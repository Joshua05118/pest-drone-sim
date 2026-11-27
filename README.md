# Lucid H7 ArduPilot simulator

Run ArduCopter and Gazebo Jetty together on a Windows x86-64 PC using Docker in WSL 2. The container includes an Iris quad-X reference airframe, a simulated GPS and compass, and an optional pair of time-of-flight (ToF) rangefinders. It runs ArduPilot's flight software on the host CPU. STM32H743 timing, board wiring, and physical sensor drivers require a hardware test.

## 1. Prepare Windows and Docker

If Docker already works in your Ubuntu WSL terminal, skip to step 2. Otherwise open PowerShell as Administrator and install Ubuntu:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart Windows if prompted. Open Ubuntu with `wsl -d Ubuntu-24.04` and finish the first-launch account setup. In PowerShell, `wsl --list --verbose` should show version 2 for Ubuntu. Run the remaining commands **inside Ubuntu**.

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo service docker start
sudo docker info
```

If you use Docker Desktop, enable WSL integration for Ubuntu and use your existing Docker CLI. You can omit `sudo` when your user already has Docker access.

## 2. Get the simulator from GitHub

### Load a release image

On the repository's **Releases** page, open the release you want and look under **Assets** for these two files:

- `lucid-sitl-jetty-linux-amd64.tar.gz` — the packaged Linux amd64 Docker image
- `lucid-sitl-jetty-linux-amd64.tar.gz.sha256` — its SHA-256 checksum

Download both to the same folder. In Ubuntu, change to that folder. Windows downloads are usually under `/mnt/c/Users/<your-Windows-user>/Downloads`. Run:

```bash
sha256sum -c lucid-sitl-jetty-linux-amd64.tar.gz.sha256 &&
  sudo docker load -i lucid-sitl-jetty-linux-amd64.tar.gz
```

Expect `OK` followed by `Loaded image: local/lucid-sitl:jetty`. The loaded image includes Gazebo, the plugin, firmware, worlds and sensor configuration. You can now run it offline.

### Build from a source ZIP or clone

Use this route if the release assets are unavailable or you want to edit the simulator. On GitHub, choose **Code → Download ZIP** and extract it, or clone the repository. In Ubuntu, open the extracted or cloned directory containing **both** Dockerfiles. Build in this order:

```bash
sudo docker build -t local/gazebo:jetty . &&
  sudo docker build -f Dockerfile.sitl -t local/lucid-sitl:jetty .
```

The first image supplies Gazebo. The second adds ArduCopter and the simulator plugin. A source build needs internet access and an x86-64 Linux Docker engine. Both installation routes produce the same local image name. The release archive preserves the tested image exactly. A fresh source build resolves the Gazebo packages and plugin revision available at build time.

## 3. Start the simulator

From any directory in Ubuntu, launch the headless simulator with both ToF sensors:

```bash
sudo docker run --rm --init --name lucid -p 127.0.0.1:5760:5760 \
  -e TOF=1 local/lucid-sitl:jetty
```

Keep the terminal open. In Mission Planner on Windows, select **TCP**, host **127.0.0.1**, port **5760**, then wait for a heartbeat and 3D GPS fix. Omit `-e TOF=1` to use the stock Iris world. Press **Ctrl+C** to stop. This command removes the container on exit, including session logs and parameter changes. The image remains available.

### Open the 3D view

Stop the headless session first. From a WSLg-enabled Ubuntu terminal, run:

```bash
sudo docker run --rm --init --name lucid -p 127.0.0.1:5760:5760 \
  -e GUI=1 -e TOF=1 -e DISPLAY="$DISPLAY" -e QT_QPA_PLATFORM=xcb \
  -e QT_X11_NO_MITSHM=1 -e LIBGL_ALWAYS_SOFTWARE=1 \
  --mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,readonly \
  local/lucid-sitl:jetty
```

## 4. Check the sensors

With the ToF example running, open a second Ubuntu terminal:

```bash
sudo docker exec lucid timeout 15 gz topic -e -t /lucid/tof/down -n 1
sudo docker exec lucid timeout 15 gz topic -e -t /lucid/tof/front -n 1
```

Look for `ranges` in metres. At rest in the reference world, the tested simulator reported about **0.21 m down** to the floor and **1.77 m forward** to the wall. In a MAVLink inspector, check `DISTANCE_SENSOR` for ID 0 with orientation 25 (down), and ID 1 with orientation 0 (forward). The integration test also received two scaled IMU streams, pressure, attitude, and a 3D GPS fix.

| Component | What the profile models |
| --- | --- |
| Lucid H7 inertial sensors | Synthetic accelerometer and gyro readings derived from Gazebo motion. The standard physical board can carry dual ICM42688 or dual MPU6000 IMUs. |
| Barometer | Simulated pressure derived from altitude. Match noise and drift to measurements from your board revision. |
| M100 GPS and compass | One GPS receiver and one navigation compass. Match the specific module's antenna offset, orientation, update rate, and latency when adapting the model. |
| Optional ToF pair | Downward and forward single beams at 20 Hz with an illustrative range of 0.05–4 m. Edit the poses in `add_range_sensors.py` and the limits and orientations in `tof.parm`, then rebuild from source. |

The image uses a checksum-pinned **ArduCopter 4.8.0-dev** build at commit `e196c29c`. Testing with 4.7.3 showed only the forward range in MAVLink. The pinned version reported both. See the [ArduPilot JSON backend](https://github.com/ArduPilot/ardupilot/blob/e196c29c73dd66a3d96acf9e78db5434eb9bf33b/libraries/SITL/SIM_JSON.cpp) and the [Lucid H7 board definition](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_HAL_ChibiOS/hwdef/TBS_LUCID_H7/hwdef.dat).

## Troubleshooting

- **Docker cannot connect.** For Docker Engine installed in Ubuntu, run `sudo service docker start` and retry `sudo docker info`. For Docker Desktop, start Desktop and check WSL integration.
- **Image missing.** Load the release archive or finish both source builds. Run `sudo docker image inspect local/lucid-sitl:jetty` using the same Docker engine as the launch command.
- **Mission Planner cannot connect.** Run `sudo docker ps` in Ubuntu and check that `lucid` publishes TCP port 5760. Read startup logs with `sudo docker logs lucid`. A client inside Ubuntu can use the same endpoint to check whether Windows localhost forwarding is the issue.
- **The GUI cannot open.** Check `echo "$DISPLAY"` and `ls -l /tmp/.X11-unix/X0` inside Ubuntu. For WSLg setup, see [Microsoft's WSL GUI guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).
