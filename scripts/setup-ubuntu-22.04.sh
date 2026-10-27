#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARDUPILOT_DIR="$HOME/ardupilot"
ARDUPILOT_COMMIT="368dc0c4289389ddb5e981d9a8b55b6ffd0d1e21"

ARDUPILOT_GAZEBO_DIR="$HOME/ardupilot_gazebo"
ARDUPILOT_GAZEBO_COMMIT="082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5"

echo "======================================"
echo "      Ubuntu 22.04 UAV Setup"
echo "======================================"

source /etc/os-release

if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
    echo "Error: This script is only for Ubuntu 22.04."
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: This setup currently supports x86_64 only."
    exit 1
fi


echo
echo "[1/11] Updating package list..."
sudo apt update


echo
echo "[2/11] Installing basic development tools..."
sudo apt install -y \
    git \
    curl \
    wget \
    gnupg \
    lsb-release \
    build-essential \
    cmake \
    pkg-config \
    terminator


echo
echo "[3/11] Installing Gazebo Harmonic..."

sudo curl \
    https://packages.osrfoundation.org/gazebo.gpg \
    --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

sudo apt update

sudo apt install -y \
    gz-harmonic \
    libgz-sim8-dev \
    rapidjson-dev \
    libopencv-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-gl


echo
echo "[4/11] Checking Miniconda..."

if [ -d "$HOME/miniconda3" ]; then
    echo "Miniconda already exists at $HOME/miniconda3"
else
    echo "Downloading Miniconda..."

    wget -O /tmp/miniconda.sh \
        https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"

    rm -f /tmp/miniconda.sh

    echo "Miniconda installed successfully."
fi

source "$HOME/miniconda3/etc/profile.d/conda.sh"


echo
echo "[5/11] Creating uav_sim environment..."

if conda env list | awk '{print $1}' | grep -qx "uav_sim"; then
    echo "uav_sim already exists."
else
    conda create -y -n uav_sim python=3.10
fi

conda run -n uav_sim python -m pip install --upgrade pip

conda run -n uav_sim python -m pip install \
    MAVProxy==1.8.72 \
    pymavlink==2.4.49 \
    pexpect \
    psutil \
    pyserial


echo
echo "[6/11] Setting up ArduPilot..."

if [ ! -d "$ARDUPILOT_DIR/.git" ]; then
    git clone https://github.com/ArduPilot/ardupilot.git "$ARDUPILOT_DIR"
fi

cd "$ARDUPILOT_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: $ARDUPILOT_DIR contains uncommitted changes."
    exit 1
fi

git fetch --all --tags
git checkout "$ARDUPILOT_COMMIT"
git submodule update --init --recursive


echo
echo "[7/11] Installing ArduPilot prerequisites..."

DO_PYTHON_VENV_ENV=0 \
Tools/environment_install/install-prereqs-ubuntu.sh -y

if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile" || true
fi


echo
echo "[8/11] Building ArduPilot SITL..."

cd "$ARDUPILOT_DIR"

./waf configure --board sitl
./waf copter


echo

# Use Gazebo Harmonic for ardupilot_gazebo
export GZ_VERSION=harmonic

echo "[9/11] Setting up ardupilot_gazebo..."

if [ ! -d "$ARDUPILOT_GAZEBO_DIR/.git" ]; then
    git clone https://github.com/ArduPilot/ardupilot_gazebo.git \
        "$ARDUPILOT_GAZEBO_DIR"
fi

cd "$ARDUPILOT_GAZEBO_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: $ARDUPILOT_GAZEBO_DIR contains uncommitted changes."
    exit 1
fi

git fetch --all --tags
git checkout "$ARDUPILOT_GAZEBO_COMMIT"

mkdir -p build
cd build

cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j"$(nproc)"


echo
echo "[10/11] Installing UAV commands..."

mkdir -p "$HOME/bin"

chmod +x "$PROJECT_ROOT/uav"
chmod +x "$PROJECT_ROOT/uav-stop"

ln -sfn "$PROJECT_ROOT/uav" "$HOME/bin/uav"
ln -sfn "$PROJECT_ROOT/uav-stop" "$HOME/bin/uav-stop"

if ! grep -Fq 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
fi


echo
echo "[11/11] Verifying installation..."

echo
echo "Gazebo:"
gz sim --versions

echo
echo "ArduCopter SITL:"
ls -lh "$ARDUPILOT_DIR/build/sitl/bin/arducopter"

echo
echo "ArduPilot Gazebo Plugin:"
ls -lh "$ARDUPILOT_GAZEBO_DIR/build/libArduPilotPlugin.so"

echo
echo "MAVProxy:"
conda run -n uav_sim python -m pip show MAVProxy | grep -E "Name|Version"

echo
echo "pymavlink:"
conda run -n uav_sim python -m pip show pymavlink | grep -E "Name|Version"

echo
echo "======================================"
echo "      Ubuntu 22.04 Setup Complete"
echo "======================================"

echo
echo "NOTE:"
echo "QGroundControl is not automatically installed on Ubuntu 22.04."
echo "Current official QGroundControl AppImage builds require Ubuntu 24.04 or newer."
echo "Ubuntu 22.04 requires a source build of QGroundControl."

echo
echo "Core simulation is ready:"
echo "Gazebo + ArduPilot SITL + MAVProxy"
