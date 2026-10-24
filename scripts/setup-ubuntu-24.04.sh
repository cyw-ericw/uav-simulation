cat > setup.sh <<'EOF'
#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        bash "$PROJECT_ROOT/scripts/setup-ubuntu-22.04.sh"
        ;;

    "24.04")
        echo "Using Ubuntu 24.04 setup..."
        bash "$PROJECT_ROOT/scripts/setup-ubuntu-24.04.sh"
        ;;

    *)
        echo "Error: Ubuntu $VERSION_ID is not supported."
        echo "Supported versions: 22.04 and 24.04"
        exit 1
        ;;
esac
EOF


cat > scripts/setup-ubuntu-24.04.sh <<'EOF'
#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARDUPILOT_DIR="$HOME/ardupilot"
ARDUPILOT_COMMIT="368dc0c4289389ddb5e981d9a8b55b6ffd0d1e21"

ARDUPILOT_GAZEBO_DIR="$HOME/ardupilot_gazebo"
ARDUPILOT_GAZEBO_COMMIT="082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5"

QGC_PATH="$HOME/Downloads/QGroundControl-x86_64.AppImage"
QGC_URL="https://d176tv9ibo4jno.cloudfront.net/builds/master/QGroundControl-x86_64.AppImage"

echo "======================================"
echo "      Ubuntu 24.04 UAV Setup"
echo "======================================"

source /etc/os-release

if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
    echo "Error: This script is only for Ubuntu 24.04."
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: This setup currently supports x86_64 only."
    exit 1
fi


echo
echo "[1/12] Updating package list..."
sudo apt update


echo
echo "[2/12] Installing basic development tools..."
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
echo "[3/12] Installing Gazebo Harmonic repository..."

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
echo "[4/12] Checking Miniconda..."

if [ -d "$HOME/miniconda3" ]; then
    echo "Miniconda already exists at $HOME/miniconda3"
else
    echo "Downloading Miniconda..."

    wget -O /tmp/miniconda.sh \
        https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

    echo "Installing Miniconda..."
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"

    rm -f /tmp/miniconda.sh

    echo "Miniconda installed successfully."
fi

source "$HOME/miniconda3/etc/profile.d/conda.sh"


echo
echo "[5/12] Creating uav_sim environment..."

if conda env list | awk '{print $1}' | grep -qx "uav_sim"; then
    echo "uav_sim already exists."
else
    conda create -y -n uav_sim python=3.10
fi

echo "Installing UAV Python packages..."

conda run -n uav_sim python -m pip install --upgrade pip

conda run -n uav_sim python -m pip install \
    MAVProxy==1.8.72 \
    pymavlink==2.4.49 \
    pexpect \
    psutil \
    pyserial


echo
echo "[6/12] Setting up ArduPilot..."

if [ ! -d "$ARDUPILOT_DIR/.git" ]; then
    git clone https://github.com/ArduPilot/ardupilot.git "$ARDUPILOT_DIR"
fi

cd "$ARDUPILOT_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: $ARDUPILOT_DIR contains uncommitted changes."
    echo "Setup will not overwrite them."
    exit 1
fi

git fetch --all --tags
git checkout "$ARDUPILOT_COMMIT"
git submodule update --init --recursive


echo
echo "[7/12] Installing ArduPilot prerequisites..."

DO_PYTHON_VENV_ENV=0 \
Tools/environment_install/install-prereqs-ubuntu.sh -y

if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile" || true
fi


echo
echo "[8/12] Building ArduPilot SITL..."


cd "$ARDUPILOT_DIR"

./waf configure --board sitl
./waf copter

if type deactivate >/dev/null 2>&1; then
    deactivate
fi


echo
echo "[9/12] Setting up ardupilot_gazebo..."

if [ ! -d "$ARDUPILOT_GAZEBO_DIR/.git" ]; then
    git clone https://github.com/ArduPilot/ardupilot_gazebo.git \
        "$ARDUPILOT_GAZEBO_DIR"
fi

cd "$ARDUPILOT_GAZEBO_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: $ARDUPILOT_GAZEBO_DIR contains uncommitted changes."
    echo "Setup will not overwrite them."
    exit 1
fi

git fetch --all --tags
git checkout "$ARDUPILOT_GAZEBO_COMMIT"

mkdir -p build
cd build

cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j"$(nproc)"


echo
echo "[10/12] Installing QGroundControl dependencies..."

sudo apt install -y \
    libfuse2 \
    libxcb-xinerama0 \
    libxkbcommon-x11-0 \
    libxcb-cursor0

sudo usermod -aG dialout "$(id -un)"

mkdir -p "$HOME/Downloads"

if [ -f "$QGC_PATH" ]; then
    echo "QGroundControl already exists:"
    echo "$QGC_PATH"
else
    echo "Downloading QGroundControl..."
    wget -O "$QGC_PATH" "$QGC_URL"
fi

chmod +x "$QGC_PATH"


echo
echo "[11/12] Installing uav and uav-stop commands..."

mkdir -p "$HOME/bin"

cp "$PROJECT_ROOT/uav" "$HOME/bin/uav"
cp "$PROJECT_ROOT/uav-stop" "$HOME/bin/uav-stop"

chmod +x "$HOME/bin/uav"
chmod +x "$HOME/bin/uav-stop"

if ! grep -Fq 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
fi


echo
echo "[12/12] Verifying installation..."

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
echo "QGroundControl:"
ls -lh "$QGC_PATH"

echo
echo "======================================"
echo "      Ubuntu 24.04 Setup Complete"
echo "======================================"
echo
echo "IMPORTANT:"
echo "Log out and log back in once so the dialout group"
echo "and PATH changes are fully applied."
echo
echo "After that, start the simulator with:"
echo
echo "    uav"
echo
echo "Stop everything with:"
echo
echo "    uav-stop"
EOF


cat > uav <<'EOF'
#!/bin/bash

set -e

echo "======================================"
echo "      UAV Simulation Environment"
echo "======================================"

if [ ! -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    echo "Error: Miniconda not found."
    exit 1
fi

if [ ! -f "$HOME/ardupilot_gazebo/build/libArduPilotPlugin.so" ]; then
    echo "Error: ArduPilot Gazebo plugin not found."
    exit 1
fi

if [ ! -f "$HOME/Downloads/QGroundControl-x86_64.AppImage" ]; then
    echo "Error: QGroundControl AppImage not found."
    exit 1
fi


echo "[1/3] Starting Gazebo..."

terminator -T "Gazebo" -e "bash -c '
export GZ_SIM_RESOURCE_PATH=\$HOME/ardupilot_gazebo/models:\$HOME/ardupilot_gazebo/worlds
export GZ_SIM_SYSTEM_PLUGIN_PATH=\$HOME/ardupilot_gazebo/build
exec gz sim -v4 -r \$HOME/ardupilot_gazebo/worlds/iris_runway.sdf
'" &

sleep 5


echo "[2/3] Starting ArduPilot SITL..."

terminator -T "ArduPilot SITL" -e "bash -c '
source \$HOME/miniconda3/etc/profile.d/conda.sh
conda activate uav_sim
cd \$HOME/ardupilot
exec Tools/autotest/sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON
'" &

sleep 3


echo "[3/3] Starting QGroundControl..."

chmod +x "$HOME/Downloads/QGroundControl-x86_64.AppImage"
"$HOME/Downloads/QGroundControl-x86_64.AppImage" &


echo
echo "======================================"
echo " UAV simulation environment launched!"
echo "======================================"
EOF


cat > uav-stop <<'EOF'
#!/bin/bash

echo "======================================"
echo "      Stopping UAV Simulation"
echo "======================================"

echo "[1/4] Stopping QGroundControl..."
pkill -f "QGroundControl" 2>/dev/null || true

echo "[2/4] Stopping MAVProxy..."
pkill -f "mavproxy.py" 2>/dev/null || true

echo "[3/4] Stopping ArduCopter SITL..."
pkill -f "build/sitl/bin/arducopter" 2>/dev/null || true
pkill -f "terminator.*ArduPilot SITL" 2>/dev/null || true

echo "[4/4] Stopping Gazebo..."
pkill -f "gz sim" 2>/dev/null || true

echo
echo "Waiting for processes to exit..."
sleep 2

pkill -9 -f "QGroundControl" 2>/dev/null || true
pkill -9 -f "mavproxy.py" 2>/dev/null || true
pkill -9 -f "build/sitl/bin/arducopter" 2>/dev/null || true
pkill -9 -f "gz sim" 2>/dev/null || true

sleep 1

echo
echo "Checking for remaining UAV processes..."

if pgrep -af "gz sim|arducopter|mavproxy|QGroundControl"; then
    echo
    echo "WARNING: Some UAV processes are still running."
else
    echo "All UAV processes stopped successfully."
fi

echo
echo "======================================"
echo " UAV simulation environment stopped."
echo "======================================"
EOF


chmod +x setup.sh
chmod +x scripts/setup-ubuntu-24.04.sh
chmod +x uav
chmod +x uav-stop

echo
echo "Files written successfully."
