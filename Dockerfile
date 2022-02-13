FROM ubuntu:18.04
MAINTAINER ipha

# Version
ARG version="3.10.13"

# Set correct environment variables
ARG DEBIAN_FRONTEND="noninteractive"

# Add needed patches and scripts
COPY root/ /

# Set up apt

RUN \
  echo "**** install packages ****" && \
  apt update && \
  apt install -y \
    patch \
    moreutils \
    jq \
    wget && \
  echo "**** install java ****" && \
  wget -q http://launchpadlibrarian.net/505954411/openjdk-8-jre-headless_8u275-b01-0ubuntu1~18.04_amd64.deb && \
  apt install -y ./openjdk-8-jre-headless_8u275-b01-0ubuntu1~18.04_amd64.deb && rm openjdk-8-jre-headless_8u275-b01-0ubuntu1~18.04_amd64.deb && \
  echo "**** install unifi-video ****" && \
  wget -q https://dl.ubnt.com/firmwares/ufv/v${version}/unifi-video.Ubuntu18.04_amd64.v${version}.deb && \
  apt install -y ./unifi-video.Ubuntu18.04_amd64.v${version}.deb && rm unifi-video.Ubuntu18.04_amd64.v${version}.deb && \
  echo "**** patching ****" && \
  patch -lN /usr/sbin/unifi-video /unifi-video.patch && rm /unifi-video.patch && \
  chmod 755 /run.sh && \
  echo "**** cleanup ****" && \
  apt clean && \
  rm -rf \
    /*.deb \
    /*.patch \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# RTMP, RTMPS & RTSP, Inbound Camera Streams & Camera Management (NVR Side), UVC-Micro Talkback (Camera Side)
# HTTP & HTTPS Web UI + API, Video over HTTP & HTTPS
EXPOSE 1935/tcp 7444/tcp 7447/tcp 6666/tcp 7442/tcp 7004/udp 7080/tcp 7443/tcp 7445/tcp 7446/tcp

# Run this potato
CMD ["/run.sh"]
