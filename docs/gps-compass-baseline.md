# Lucid H7 and HGLRC M100-5883 baseline

Run the existing ArduCopter and Gazebo simulation with a GPS receiver and compass, then verify the physical flight controller and module over USB. The simulated vehicle retains its IMUs and barometer. Leave the ToF sensors out of both tests.

## 1. Get the development branch

In PowerShell, check for Windows Subsystem for Linux and Ubuntu 24.04.

```powershell
wsl --list --verbose
```

If Ubuntu-24.04 is missing, open an administrator PowerShell and run `wsl --install -d Ubuntu-24.04`. Restart Windows if prompted and complete Ubuntu's first-launch account setup. The distro must show version 2. If it shows version 1, run `wsl --set-version Ubuntu-24.04 2` in PowerShell. Open it with `wsl -d Ubuntu-24.04`. [Microsoft WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install)

Run the rest of the Git and Docker commands inside Ubuntu. Use your existing Docker engine if `sudo docker info` works. For a fresh setup with Docker Engine in WSL, run the following. If using Docker Desktop instead, enable Ubuntu WSL integration and use its Docker CLI without installing a second engine.

```bash
sudo apt-get update
sudo apt-get install -y git docker.io
sudo service docker start
sudo docker info
```

For a fresh checkout, run the following from your Ubuntu home folder or another parent directory.

```bash
git clone --branch dev/gps-compass https://github.com/Joshua05118/pest-drone-sim.git
cd pest-drone-sim
git status --short --branch
```

For an existing clone, first check `git status` and save any in-progress edits. Run the following from the repository folder.

```bash
git fetch origin
git switch dev/gps-compass
git pull --ff-only
git status --short --branch
```

The status should show `dev/gps-compass` tracking `origin/dev/gps-compass`.

## 2. Run the existing simulator profile

Check for the local image.

```bash
sudo docker image inspect local/lucid-sitl:jetty --format '{{.Id}}'
```

If the image is missing, [load the archive](../README.md#load-a-release-image) if you have it or build from the checkout. A source build requires internet access and an x86-64 Linux Docker engine.

```bash
sudo docker build -t local/gazebo:jetty . &&
  sudo docker build -f Dockerfile.sitl -t local/lucid-sitl:jetty .
```

From Ubuntu, launch the simulator without the ToF option.

```bash
sudo docker run --rm --init --name lucid-gps +  -p 127.0.0.1:5760:5760 local/lucid-sitl:jetty
```

On Windows, open Mission Planner and connect via **TCP** to **127.0.0.1**, port **5760**. Keep the container terminal open. [Mission Planner installation guide](https://ardupilot.org/planner/docs/mission-planner-installation.html)

1. Confirm a MAVLink heartbeat and stable attitude while the model is stationary.
2. In the MAVLink Inspector, check `GPS_RAW_INT`. Wait for `fix_type` of at least 3. Record `satellites_visible` and any reported accuracy. The current simulator can report a higher fix type than the physical M100.
3. In `RAW_IMU`, check that the three magnetic field components (`xmag`, `ymag`, `zmag`) form a nonzero vector. Check that the HUD heading settles. Confirm `GPS2_TYPE=0`, `COMPASS_USE2=0`, and `COMPASS_USE3=0` in the parameter list.
4. Record the image ID and Git commit from `git rev-parse --short HEAD`. On the tested local image, the stock profile reported a fix type of 6, 10 satellites, a nonzero magnetometer vector, and attitude. These are simulator results.

Press Ctrl+C to stop the disposable session. Copy any onboard log you want to keep before exiting, or save Mission Planner's telemetry log. Use a second Ubuntu terminal with `sudo docker logs lucid-gps` for startup diagnostics. If the Windows TCP connection fails, check `sudo docker ps` for the port mapping and try a MAVLink client inside Ubuntu to isolate Windows localhost forwarding.

## 3. Check the physical board and module

Use a disarmed bench setup. Remove propellers and leave motor power disconnected. Confirm the exact Lucid H7 variant from its markings and pinout before connecting anything. The mapping below assumes the standard TBS Lucid H7. [ArduPilot Lucid H7 board guide](https://ardupilot.org/copter/docs/common-tbs-lucidh7.html) · [TBS Lucid manual](https://www.team-blacksheep.com/media/files/tbs-lucid-manual.pdf)

1. Plug the bare controller into Windows using a USB data cable. If ArduPilot is already installed, connect Mission Planner to the Windows COM port, record the detected board and firmware, and save the parameters. If the board needs its first ArduPilot install, identify the exact target first and follow the board guide's DFU instructions for the matching `with_bl.hex` file. Use the board firmware for the physical controller. The Linux SITL executable runs in Docker.
2. Disconnect power before wiring. Use pad labels and the pinouts for both boards. Confirm that the UART is free and that the chosen supply pad is compatible. The module is specified for 3.3–5 V. Verify whether the selected pad is powered by USB alone before judging sensor detection. If a separate supply is needed, use the board's documented power input and keep motors disconnected. [HGLRC module specifications](https://www.hglrc.com/products/m100-5883-gps)

   | M100-5883 pad | Standard Lucid H7 connection |
   | --- | --- |
   | TX | R2 / UART2 RX |
   | RX | T2 / UART2 TX |
   | SDA | External SDA |
   | SCL | External SCL |
   | GND | Ground |
   | Power | Verified compatible supply pad as specified for both boards |

3. Reconnect over USB and check the GPS port and receiver settings. For UART2 on the standard board, check that `SERIAL2_PROTOCOL` is GPS (5). Start with ArduPilot's receiver autodetection and configuration defaults. HGLRC lists 115200 baud and 10 Hz. Record what ArduPilot actually configures and receives. If there is no GPS detection, check power and the crossed UART lines, then compare the baud and receiver protocol settings against the module and firmware documentation. [ArduPilot parameter reference](https://ardupilot.org/copter/docs/parameters.html)
4. Put the antenna outdoors with an open sky view. Check for a 3D fix and log the time from module power-on to fix, satellite count, HDOP if available, and stable position. In Mission Planner's Compass setup screen, check for one detected external compass. Record its device ID and orientation. The standard Lucid H7 has no onboard compass.
5. Mount the module and controller rigidly in their intended orientations, away from magnetic interference. Calibrate the compass using Mission Planner with a good GPS fix. Reboot as prompted. With the assembly level, point the vehicle nose along known headings and confirm the displayed heading turns in the correct direction and settles near each reference. Compare like with like when the reference uses magnetic north and Mission Planner displays true heading. [ArduPilot compass calibration guide](https://ardupilot.org/copter/docs/common-compass-calibration-in-mission-planner.html)
6. Save the configured parameters and record a stationary sample of GPS and magnetometer data. A 60–120 second Mission Planner telemetry log after the fix is sufficient for an initial comparison. Record the conditions and sample interval. If using the onboard DataFlash log, enable disarmed logging for the bench capture and restore the previous setting afterward.

## 4. Share the measurements for tuning

For a first pass, send the board revision, both mounting orientations, the module offset, and one log with a 3D fix. A labeled photo or sketch works for the mounting information. Keep hardware parameter exports as reference data.

| Send | Why it matters |
| --- | --- |
| Lucid H7 revision, ArduPilot board target and firmware version | Identifies the physical firmware and onboard sensors to compare. |
| M100-5883 label or PCB revision, UART used, detected GPS protocol, and compass device ID | Confirms which hardware and interfaces passed the bench test. |
| Vehicle forward direction, FC orientation, and M100 arrow direction with roll/pitch/yaw if known | Establishes the coordinate frames. State whether the mounting is final or temporary. |
| GPS antenna position relative to the vehicle reference point, in metres, with X forward, Y right, Z down | Sets the antenna offset when the airframe geometry is available. |
| GPS update rate, time to 3D fix, satellites, and horizontal/vertical position scatter or a log | Provides measured values for GPS timing and noise. The advertised 10 Hz is a starting assumption until measured. |
| Compass calibration result and observed heading at two or more known orientations, or a log with reference headings | Helps separate axis alignment from magnetic interference and bias. |

Use the physical measurements to set the SITL GPS rate, lock time, lag and noise as appropriate. The current branch uses the existing reference configuration. Keep hardware calibration offsets and the complete physical-board parameter file with that board. [ArduPilot SITL parameters](https://ardupilot.org/copter/docs/parameters.html#sim-gps1-hz-gps-hz)
