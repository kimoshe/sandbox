# ABOUT
# Appends a signature based on the version and revision to __init.py__

# LICENSE
# This program or module is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 2 of the License, or
# version 3 of the License, or (at your option) any later version. It is
# provided for educational purposes and is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# AUTHOR
# Dave Baxter, 2026

import os
import sys
import re
import base64
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

def read_init_file(filepath: str) -> str:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content: str = f.read()
    except FileNotFoundError:
        print(f'ERROR: File not found: {filepath}')
        sys.exit(1)
    except OSError as e:
        print(f'ERROR: Failed to read file {filepath}: {e}')
        sys.exit(1)
    
    return content

def extract_field(content: str, field_name: str) -> str | None:
    # Extract a field value from the __init__.py content
    pattern: str = rf'^__{field_name}__\s*=\s*[\'"]([^\'"]*)[\'"]'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return match.group(1)
    return None

def load_private_key() -> ed25519.Ed25519PrivateKey:
    # ARTISAN_KEY environment variable is set in the Appveyor environment
    key_env: str | None = os.environ.get('ARTISAN_KEY')
    if not key_env:
        print('ERROR: ARTISAN_KEY environment variable not set.')
        sys.exit(1)
    
    try:
        # Decode base64 to get DER bytes
        key_bytes: bytes = base64.b64decode(key_env)
        
        # Load DER-formatted key
        private_key = serialization.load_der_private_key(
            key_bytes,
            password=None  # No passphrase
        )
        
        # Verify it's an Ed25519 key
        if not isinstance(private_key, ed25519.Ed25519PrivateKey):
            print('ERROR: Private key is not an Ed25519 key.')
            sys.exit(1)
        
        return private_key
    except ValueError as e:
        print(f'ERROR: Failed to load private key: {e}')
        sys.exit(1)
    except OSError as e:
        print(f'ERROR: Failed to load private key: {e}')
        sys.exit(1)

def generate_signature(
        private_key: ed25519.Ed25519PrivateKey,
        revision: str,
        version: str,
        operating_system: str) -> str:
    print(f'{revision}:{version}:{operating_system}')  #TODO remove
    # Generate the ed25519 signature
    message: bytes = bytes(f'{revision}:{version}:{operating_system}', encoding='ascii')
    signature_bytes: bytes = private_key.sign(message)
    # Convert to hex string
    signature_hex: str = signature_bytes.hex()
    return signature_hex

def remove_existing_signature(content: str) -> str:
    # Remove an existing __signature__ line from content if it exists
    content = re.sub(
        r'^__signature__\s*=\s*[\'"]([^\'"]*)[\'"]\n',
        '',
        content,
        flags=re.MULTILINE
    )
    return content

def write_signature_to_file(filepath: str, signature_hex: str) -> None:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content: str = f.read()
        
        # Remove existing __signature__ line if it exists
        content = remove_existing_signature(content)
        
        # Append the new signature
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            f.write(f'__signature__ = \'{signature_hex}\'\n')
    except OSError as e:
        print(f'ERROR: Failed to write signature to file: {e}')
        sys.exit(1)
        
def get_operating_system(content: str) -> str:
    """
    Determine the operating system either from Appveyor or from file content.
    
    If running on Appveyor (APPVEYOR env var set to true/True/TRUE):
        - Maps APPVEYOR_JOB_NAME: "windows" -> "Windows", "macos" -> "Darwin", "linux" -> "Linux"
        - Returns unmapped values verbatim with a warning
        - Returns empty string if APPVEYOR_JOB_NAME doesn't exist (with warning)
    
    If not on Appveyor:
        - Extracts operating_system from file content via extract_field()
        - Exits with error if not found in content
    
    Args:
        content: The content of the __init__.py file
    
    Returns:
        str: The operating system name
    """
    appveyor_env: str | None = os.environ.get("APPVEYOR", "").lower()
    is_appveyor: bool = appveyor_env in ["true", "1", "yes"]
    
    if is_appveyor:
        #TODO this is a test, delete this bit
        test_name: str | None = os.environ.get("APPVEYOR_XXX")
        if not test_name:
            print("Warning: APPVEYOR_XXX environment variable not found")


        job_name: str | None = os.environ.get("APPVEYOR_JOB_NAME")
        
        if not job_name:
            print("Warning: APPVEYOR_JOB_NAME environment variable not found")  #TODO this might ought to be a fatal error
            return ""
        
        mapping: dict[str, str] = {
            "windows": "Windows",
            "macos": "Darwin",
            "linux": "Linux"
        }
        
        if job_name.lower() in mapping:  #TODO no need for lower() here)
            return mapping[job_name.lower()]
        else:
            print(f"Warning: Unknown APPVEYOR_JOB_NAME value: {job_name}")
            return job_name
    else:
        operating_system: str | None = extract_field(content, 'operating_system')
        
        if operating_system is None:
            print("ERROR: operating_system not found in file content")
            sys.exit(1)
        
        return operating_system



def main() -> None:
    # Set the file path
    init_filepath: str = os.path.join('artisanlib', '__init__.py')
    
    # Read the file
    content = read_init_file(init_filepath)
    
    # Extract version and revision
    version: str | None = extract_field(content, 'version')
    revision: str | None = extract_field(content, 'revision')
    operating_system: str = get_operating_system(content)
    print(f"Operating System: {operating_system}")  #dave #TODO
    
    # Warn if fields are missing but continue
    if not version:
        print('WARNING: __version__ not found in __init__.py')
    if not revision:
        print('WARNING: __revision__ not found in __init__.py')
    
    # Load the private key
    private_key: ed25519.Ed25519PrivateKey = load_private_key()
    
    # Generate the signature
    signature_hex: str = generate_signature(private_key, revision or '', version or '', operating_system or '')
    
    # Write the signature to the file (replaces if it exists)
    write_signature_to_file(init_filepath, signature_hex)
    
    print('Signature written successfully.')
    print(f'Signature: {signature_hex}')

if __name__ == '__main__':
    main()
