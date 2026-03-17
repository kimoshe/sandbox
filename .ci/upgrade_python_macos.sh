#!/bin/bash

# Check if the input is provided
if [ -z "$1" ]; then
    echo "Usage: $0 major.minor"
    exit 1
fi

# Assign input to a variable
VERSION="$1"

# Validate the input format (major.minor)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use major.minor format (e.g., 3.14)."
    exit 1
fi

# Construct the URL to fetch available versions
BASE_URL="https://www.python.org/ftp/python/"
RELEASES=$(curl -s "$BASE_URL" | grep -oP "${VERSION}\.\d+(?=\/)" | sort -V)

# Check if we found any releases
if [ -z "$RELEASES" ]; then
    echo "No releases found for version $VERSION."
    exit 1
fi

# Get the latest release
LATEST_RELEASE=$(echo "$RELEASES" | tail -n 1)

# Construct the download link for macOS
DOWNLOAD_LINK="${BASE_URL}${LATEST_RELEASE}/python-${LATEST_RELEASE}-macos11.pkg"

# Output the download link
echo "$DOWNLOAD_LINK"