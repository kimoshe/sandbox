#!/usr/bin/env python
import subprocess
import sys
import os

# Redirect print to stderr
_print = print
def print(*args, **kwargs):
    kwargs['file'] = sys.stderr
    _print(*args, **kwargs)

project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
project_root_src = os.path.dirname(os.path.abspath(__file__))

# Determine the venv Python path based on OS
if sys.platform.startswith('win32'):
    venv_python = os.path.join(project_root, '.venv', 'Scripts', 'python')
elif sys.platform.startswith('darwin'):
    venv_python = os.path.join(project_root, '.venv', 'bin', 'python')
elif sys.platform.startswith('linux'):
    venv_python = os.path.join(project_root, '.venv', 'bin', 'python')
else:
    print(f"INFO: Skipping signature update on {sys.platform}")
    sys.exit(0)

try:
    result = subprocess.run(
        [venv_python, 'generate_signature.py'],
        cwd=project_root_src,
        check=True
    )
except (FileNotFoundError, NameError) as e:
    print(f'EXCEPTION: subprocess() {e}')
    sys.exit(1)

sys.exit(result.returncode)
