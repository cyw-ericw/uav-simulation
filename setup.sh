#!/bin/bash

set -e

echo "======================================"
echo "      UAV Simulation Setup"
echo "======================================"

if [ ! -f /etc/os-release ]; then
    echo "Error: Cannot detect Ubuntu version."
    exit 1
fi

source /etc/os-release

echo "Detected OS: $PRETTY_NAME"
echo

case "$VERSION_ID" in
    "22.04")
        echo "Using Ubuntu 22.04 setup..."
        bash scripts/setup-ubuntu-22.04.sh
        ;;

    "24.04")
        echo "Using Ubuntu 24.04 setup..."
        bash scripts/setup-ubuntu-24.04.sh
        ;;

    *)
        echo "Error: Ubuntu $VERSION_ID is not supported."
        echo "Supported versions: 22.04 and 24.04"
        exit 1
        ;;
esac
