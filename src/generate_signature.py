#!/usr/bin/env python3
"""
Sign the artisan package with Ed25519.
Reads version and revision from src/artisanlib/__init__.py,
generates a signature, and appends it to the file.
"""

import base64
import os
import re
import sys
from typing import Optional
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization


def read_init_file(filepath: str) -> str:
    """Read the __init__.py file and extract version and revision."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content: str = f.read()
    except FileNotFoundError:
        print(f"ERROR: File not found: {filepath}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to read file {filepath}: {e}")
        sys.exit(1)
    
    return content


def extract_field(content: str, field_name: str) -> Optional[str]:
    """Extract a field value from the __init__.py content."""
    pattern: str = rf"^__{field_name}__\s*=\s*['\"]([^'\"]*)['\"]"
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return match.group(1)
    return None


def remove_existing_signature(content: str) -> str:
    """Remove existing __signature__ line from content if present."""
    content = re.sub(r"^__signature__\s*=\s*['\"]([^'\"]*)['\"]\n", '', content, flags=re.MULTILINE)
    return content


def load_private_key() -> ed25519.Ed25519PrivateKey:
    """Load the Ed25519 private key from the ARTISAN_KEY environment variable."""
    key_env: Optional[str] = os.environ.get('ARTISAN_KEY')
    if not key_env:
        print("ERROR: ARTISAN_KEY environment variable not set.")
        sys.exit(1)
    
    try:
        # Decode base64 to get DER bytes
        key_bytes: bytes = base64.b64decode(key_env)
        
        # Load DER-formatted private key
        private_key = serialization.load_der_private_key(
            key_bytes,
            password=None  # No passphrase
        )
        
        # Verify it's an Ed25519 key
        if not isinstance(private_key, ed25519.Ed25519PrivateKey):
            print("ERROR: Private key is not an Ed25519 key.")
            sys.exit(1)
        
        return private_key
    except Exception as e:
        print(f"ERROR: Failed to load private key: {e}")
        sys.exit(1)


def generate_signature(private_key: ed25519.Ed25519PrivateKey, revision: str, version: str) -> str:
    """Generate the Ed25519 signature."""
    message: bytes = bytes(f'{revision}:{version}', encoding='ascii')
    signature_bytes: bytes = private_key.sign(message)
    # Convert to hex string
    signature_hex: str = signature_bytes.hex()
    return signature_hex


def write_signature_to_file(filepath: str, signature_hex: str) -> None:
    """Write or replace the __signature__ variable in the file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content: str = f.read()
        
        # Remove existing __signature__ line if present
        content = remove_existing_signature(content)
        
        # Append the new signature
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            f.write(f"__signature__ = '{signature_hex}'\n")
    except Exception as e:
        print(f"ERROR: Failed to write signature to file: {e}")
        sys.exit(1)


def main() -> None:
    """Main entry point."""
    init_filepath: str = os.path.join('artisanlib', '__init__.py')
    
    # Read the file
    content = read_init_file(init_filepath)
    
    # Extract version and revision
    version: Optional[str] = extract_field(content, 'version')
    revision: Optional[str] = extract_field(content, 'revision')
    
    # Warn if fields are missing but continue
    if not version:
        print("WARNING: __version__ not found in __init__.py")
    if not revision:
        print("WARNING: __revision__ not found in __init__.py")
    
    # Load the private key
    private_key: ed25519.Ed25519PrivateKey = load_private_key()
    
    # Generate the signature
    signature_hex: str = generate_signature(private_key, revision or '', version or '')
    
    # Write the signature to the file (replaces if it exists)
    write_signature_to_file(init_filepath, signature_hex)
    
    print(f"Signature written successfully.")
    print(f"Signature: {signature_hex}")


if __name__ == '__main__':
    main()
