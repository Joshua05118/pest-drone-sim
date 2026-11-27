FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg -o /usr/share/keyrings/gazebo.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/gazebo.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable noble main" > /etc/apt/sources.list.d/gazebo.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gz-jetty libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/*

COPY world.sdf /opt/gazebo/world.sdf
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["gz", "sim"]
CMD ["-s", "-r", "/opt/gazebo/world.sdf"]
