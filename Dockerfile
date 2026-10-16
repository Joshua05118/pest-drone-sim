FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV GZ_VERSION=harmonic

# Tools for installing packages and building the simulation.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    build-essential \
    cmake \
    pkg-config \
    python3 \
    python3-venv \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Official Gazebo package repository for Ubuntu 24.04.
RUN curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable noble main" \
        > /etc/apt/sources.list.d/gazebo-stable.list

# Gazebo Harmonic and ArduPilot–Gazebo plugin dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gz-harmonic \
    libgz-sim8-dev \
    rapidjson-dev \
    libopencv-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-gl \
    && rm -rf /var/lib/apt/lists/*

# Explicit dependency required by Gazebo Transport on Ubuntu 24.04.
RUN apt-get update \
    && apt-get install -y --no-install-recommends cppzmq-dev \
    && rm -rf /var/lib/apt/lists/*
# Build a specific revision of the ArduPilot–Gazebo plugin.
ARG GAZEBO_PLUGIN_COMMIT

RUN test -n "${GAZEBO_PLUGIN_COMMIT}" \
    && git clone https://github.com/ArduPilot/ardupilot_gazebo.git \
        /opt/ardupilot_gazebo \
    && git -C /opt/ardupilot_gazebo checkout --detach \
        "${GAZEBO_PLUGIN_COMMIT}" \
    && cmake -S /opt/ardupilot_gazebo \
        -B /opt/ardupilot_gazebo/build \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && cmake --build /opt/ardupilot_gazebo/build -j2

ENV GZ_SIM_SYSTEM_PLUGIN_PATH=/opt/ardupilot_gazebo/build
ENV GZ_SIM_RESOURCE_PATH=/opt/ardupilot_gazebo/models:/opt/ardupilot_gazebo/worlds

# Run ArduPilot's dependency installer as a non-root build user.
RUN useradd --create-home --shell /bin/bash sim \
    && echo "sim ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sim \
    && chmod 0440 /etc/sudoers.d/sim \
    && mkdir -p /opt/ardupilot /workspace \
    && chown sim:sim /opt/ardupilot /workspace

# Pin ArduPilot to the revision already tested on your computer.
ARG ARDUPILOT_COMMIT=b032bcbde31a8649d748baa5e5910208a76460f2

RUN sudo -u sim -H git clone \
        https://github.com/ArduPilot/ardupilot.git /opt/ardupilot \
    && sudo -u sim -H git -C /opt/ardupilot \
        checkout --detach "${ARDUPILOT_COMMIT}" \
    && sudo -u sim -H git -C /opt/ardupilot \
        submodule update --init --recursive

# Put Python dependencies in a predictable location.
RUN sudo -u sim -H python3 -m venv --system-site-packages \
        /opt/ardupilot/venv-ardupilot

# Install SITL dependencies without the hardware-flashing toolchain
# or MAVProxy's optional graphical windows.
RUN cd /opt/ardupilot \
    && sudo -u sim -H env \
        USER=sim \
        SKIP_AP_GRAPHIC_ENV=1 \
        SKIP_AP_COV_ENV=1 \
        SKIP_AP_COMPLETION_ENV=1 \
        SKIP_AP_GIT_CHECK=1 \
        DO_AP_STM_ENV=0 \
        DO_PYTHON_VENV_ENV=0 \
        AP_DOCKER_BUILD=1 \
        bash Tools/environment_install/install-prereqs-ubuntu.sh -y

ENV PATH="/opt/ardupilot/venv-ardupilot/bin:/opt/ardupilot/Tools/autotest:${PATH}"

RUN sudo -u sim -H bash -c \
    'source /opt/ardupilot/venv-ardupilot/bin/activate && \
     cd /opt/ardupilot && \
     ./waf configure --board sitl && \
     ./waf copter -j2'

USER sim

WORKDIR /workspace

CMD ["/bin/bash"]
