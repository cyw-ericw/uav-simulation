# UAV Simulation Environment

Automated setup for an ArduPilot UAV simulation environment on Ubuntu.

This project is designed to reproduce the UAV simulation environment across different computers, including Ubuntu 22.04 and Ubuntu 24.04 systems.

## Architecture

```text
Gazebo Harmonic
      ↕ JSON
ArduPilot SITL
      ↕ MAVLink
MAVProxy
      ↓ UDP 14550
QGroundControl
```

### Components

- **Gazebo Harmonic** — UAV simulation environment and physics
- **ArduPilot SITL** — simulated ArduCopter flight controller
- **MAVProxy** — MAVLink communication and forwarding
- **QGroundControl** — ground control station
- **Miniconda** — Python environment management
- **ardupilot_gazebo** — communication plugin between Gazebo and ArduPilot

## Supported Systems

| Ubuntu Version | Gazebo | ArduPilot SITL | MAVProxy | QGroundControl |
|---|---|---|---|---|
| Ubuntu 24.04 | Yes | Yes | Yes | Yes |
| Ubuntu 22.04 | Yes | Yes | Yes | Not automatically installed |

The setup script automatically detects the Ubuntu version and runs the corresponding installation script.

## Installation

Clone this repository:

```bash
git clone git@github.com:cyw-ericw/uav-simulation.git
cd uav-simulation
```

Make the setup script executable:

```bash
chmod +x setup.sh
```

Run:

```bash
./setup.sh
```

The installer will detect the Ubuntu version automatically.

```text
setup.sh
   │
   ├── Ubuntu 22.04
   │      └── scripts/setup-ubuntu-22.04.sh
   │
   └── Ubuntu 24.04
          └── scripts/setup-ubuntu-24.04.sh
```

## Start the Simulation

After installation, open a new terminal and run:

```bash
uav
```

This starts:

```text
Gazebo
   ↓
ArduPilot SITL
   ↓
MAVProxy
   ↓
QGroundControl (if available)
```

On systems without QGroundControl, Gazebo and ArduPilot SITL will continue running.

## Stop the Simulation

Run:

```bash
uav-stop
```

This stops the UAV simulation processes, including:

- QGroundControl
- MAVProxy
- ArduPilot SITL
- Gazebo

## Reproducible Versions

The project pins important components to known versions or Git commits.

### ArduPilot

Repository:

```text
https://github.com/ArduPilot/ardupilot
```

Commit:

```text
368dc0c4289389ddb5e981d9a8b55b6ffd0d1e21
```

### ardupilot_gazebo

Repository:

```text
https://github.com/ArduPilot/ardupilot_gazebo
```

Commit:

```text
082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5
```

### Python Environment

Conda environment:

```text
uav_sim
```

Python:

```text
3.10
```

Important Python packages:

```text
MAVProxy 1.8.72
pymavlink 2.4.49
```

### Gazebo

The simulation uses:

```text
Gazebo Harmonic
```

The known working Ubuntu 24.04 development machine currently uses Gazebo Sim 8.15.0.

## Project Structure

```text
uav-simulation/
├── README.md
├── setup.sh
├── uav
├── uav-stop
└── scripts/
    ├── setup-ubuntu-22.04.sh
    └── setup-ubuntu-24.04.sh
```

### setup.sh

Detects the Ubuntu version and selects the appropriate setup script.

### setup-ubuntu-22.04.sh

Installs and builds the core UAV simulation environment for Ubuntu 22.04.

### setup-ubuntu-24.04.sh

Installs and builds the UAV simulation environment for Ubuntu 24.04.

### uav

Starts the simulation environment.

### uav-stop

Stops the simulation environment and cleans up remaining simulation processes.

## Simulation World

Default Gazebo world:

```text
~/ardupilot_gazebo/worlds/iris_runway.sdf
```

Default vehicle configuration:

```text
ArduCopter
gazebo-iris
```

ArduPilot SITL is launched using:

```bash
Tools/autotest/sim_vehicle.py \
    -v ArduCopter \
    -f gazebo-iris \
    --model JSON
```

## Notes

Do not copy compiled binaries or Gazebo plugins directly between Ubuntu 22.04 and Ubuntu 24.04 systems.

Each computer should compile ArduPilot and `ardupilot_gazebo` locally using the setup scripts.

This helps avoid incompatibilities caused by differences in system libraries, compilers, and Ubuntu versions.

## Current Status

Ubuntu 24.04:

```text
Gazebo              Working
ArduPilot SITL      Working
MAVProxy            Working
QGroundControl      Working
uav command         Working
uav-stop command    Working
```




Ubuntu 22.04:

```text
Setup script        Prepared
Syntax check        Passed
Real-machine test   Pending
```
