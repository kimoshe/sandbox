import urllib.request
import gzip
import re
import sys

def get_latest_python_release(major_minor):
    url = 'https://www.python.org/downloads/'
    try:
        with urllib.request.urlopen(url) as response:
            html = gzip.decompress(response.read()).decode('utf-8')
        pattern = rf'Python ({re.escape(major_minor)}\.\d+)'
        match = re.search(pattern, html)
        if match:
            return match.group(1)
    except Exception as e:
        print(f"ERROR: Failed to retrieve latest release: {e}", file=sys.stderr)
        return '0.0.0'

    print(f"ERROR: Could not find Python {major_minor}", file=sys.stderr)
    return '0.0.0'

if __name__ == '__main__':
    version = get_latest_python_release(sys.argv[1] if len(sys.argv) > 1 else '3.13')
    print(version)
