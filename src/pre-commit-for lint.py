#!/usr/bin/env python
# ABOUT
# Pre-commit hook that runs pre-commit checks and generates signatures.
# Works on Windows, macOS, and Linux.

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
# Dave Baxter, Marko Luther 2026

import sys
import subprocess
from pathlib import Path


def get_repo_root() -> Path:
    # Get the absolute path to the repository root.
    return Path(__file__).resolve().parent.parent.parent

def run_command(cmd: list[str], cwd: Path | None = None, timeout: int = 300) -> int:
    #Run a command and return the exit code
    if cwd is None:
        cwd = get_repo_root()

    try:
        result = subprocess.run(cmd, cwd=cwd, timeout=timeout, check=False)
        return result.returncode

    except subprocess.TimeoutExpired:
        print(f"Error: Command timed out after {timeout} seconds: {' '.join(cmd)}")
        return 1
    except FileNotFoundError:
        print(f'Error: Command not found: {cmd[0]}')
        return 1
    except OSError as e:
        print(f"Error running command {' '.join(cmd)}: {e}")
        return 1

def run_command_capture_output(cmd: list[str], cwd: Path | None = None, timeout: int = 60) -> tuple[int, str, str]:
    # Run a command and return the exit code, stdout and stderr
    if cwd is None:
        cwd = get_repo_root()

    try:
        result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False)
        return result.returncode, result.stdout, result.stderr

    except subprocess.TimeoutExpired:
        print(f"Error: Command timed out after {timeout} seconds: {' '.join(cmd)}")
        return 1, '', ''
    except FileNotFoundError:
        print(f'Error: Command not found: {cmd[0]}')
        return 1, '', ''
    except OSError as e:
        print(f"Error running command {' '.join(cmd)}: {e}")
        return 1, '', ''

def main() -> int:
    #Execute pre-commit checks and generate a signature in src/artisanlib/__init__.py
    print('Now running: .git/hooks/pre-commit')

    # Absolute repository path
    repo_root: Path = get_repo_root()

    # Determine absolute Python executable path
    venv_python: Path = (
        repo_root / '.venv' / 'Scripts' / 'python.exe'
        if sys.platform == 'win32'
        else repo_root / '.venv' / 'bin' / 'python'
    )
    if not venv_python.exists():
        print('Error: Python executable not found in .venv')
        print(f'Expected at: {venv_python}')
        return 1

    # Determine absolute pre-commit executable path
    precommit_exe: Path = (
        repo_root / '.venv' / 'Scripts' / 'pre-commit.exe'
        if sys.platform == 'win32'
        else repo_root / '.venv' / 'bin' / 'pre-commit'
    )
    if not precommit_exe.exists():
        print(f'Error: pre-commit executable not found at {precommit_exe}')
        return 1

    # Set absolute path and string relative path
    init_file: Path = repo_root / 'src' / 'artisanlib' / '__init__.py'
    init_file_relative: str = 'src/artisanlib/__init__.py'


    #
    # Step 1: Show the git version
    #
    exit_code, stdout, _stderr = run_command_capture_output(
        ['git', '--version'],
        cwd=repo_root,
        timeout=10
    )
    if exit_code != 0:
        print('Error: git --version failed')
        return 1
    print(f'{stdout.strip()}')

    #
    # Step 2: Run pre-commit framework checks
    #
    print('Running pre-commit checks...')
    exit_code = run_command(
        [str(precommit_exe), 'run', '--hook-stage', 'pre-commit'],
        cwd=repo_root
    )
    if exit_code != 0:
        print('Error: Pre-commit checks failed')
        return 1

    #
    # Step 3a: Check if __init__.py has changes before generating signature
    #
    print('Checking if __init__.py has changes...')

    exit_code, stdout, _stderr = run_command_capture_output(
        ['git', 'diff', '--name-only', 'HEAD'],
        cwd=repo_root,
        timeout=10
    )
    if exit_code != 0:
        print('Error: git diff --name-only HEAD failed')
        return 1

    if init_file_relative in stdout.split('\n'):
        print('Changes detected in __init__.py')
    else:
        print('No changes detected in __init__.py')
        # for information only, continuing to check if the file is staged regardless
        #return 0

    #
    # Step 3b: Check if __init__.py is staged before generating signature
    #
    print('Checking if __init__.py is staged...')

    exit_code, stdout, _stderr = run_command_capture_output(
        ['git', 'diff', '--cached', '--name-only'],
        cwd=repo_root,
        timeout=10
    )
    if exit_code != 0:
        print('Error: git diff --cached --name-only failed')
        return 1

    staged_files: list[str] = stdout.strip().split('\n') if stdout.strip() else []

    if init_file_relative not in staged_files:
        print('Skipping signature generation: __init__.py is not staged')
        print('Pre-commit hook completed successfully')
        return 0

    #
    # Step 4: Run signature generation script
    #
    print('Running signature generation...')
    src_dir: Path = repo_root / 'src'
    if not src_dir.exists():
        print(f'Error: src folder not found in {repo_root}')
        return 1

    signature_script: Path = src_dir / 'generate_signature.py'
    if not signature_script.exists():
        print(f'Error: generate_signature.py not found in {src_dir}')
        return 1

    exit_code = run_command(
        [str(venv_python), str(signature_script)],
        cwd=src_dir
    )
    if exit_code != 0:
        print('Error: Signature generation failed')
        return 1

    #
    # Step 5: Re-stage the modified __init__.py
    #
    print('Re-staging __init__.py')
    if not init_file.exists():
        print(f'Error: __init__.py not found at {init_file}')
        return 1

    exit_code = run_command(
        ['git', 'add', str(init_file)],
        cwd=repo_root,
        timeout=10
    )
    if exit_code != 0:
        print('Error: git add failed')
        return 1

    print('Pre-commit hook completed successfully')
    return 0

if __name__ == '__main__':
    sys.exit(main())
