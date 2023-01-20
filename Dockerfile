# syntax=docker/dockerfile:1
ARG ARCH=
FROM ${ARCH}ubuntu:22.04
LABEL Description="CORE Docker Ubuntu Image"

# define variables
ARG PREFIX=/usr/local
#ARG BRANCH=master
ARG BRANCH=release-9.0.1

# define environment
ENV DEBIAN_FRONTEND=noninteractive

# install basic dependencies
RUN apt-get update && \
  apt-get install -y git sudo wget tzdata python3 python3-pip python3-venv && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# install core
WORKDIR /opt
RUN git clone https://github.com/coreemu/core
WORKDIR /opt/core
RUN git checkout ${BRANCH}
#RUN NO_SYSTEM=1 ./setup.sh
RUN ./setup.sh
RUN apt-get update && . /root/.bashrc && inv install -v -p ${PREFIX} && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
ENV PATH "$PATH:/opt/core/venv/bin"

# install emane
#RUN apt-get install -y libpcap-dev libpcre3-dev libprotobuf-dev libxml2-dev protobuf-compiler uuid-dev && \
RUN apt-get update && apt-get install -y libpcap-dev libpcre3-dev libxml2-dev uuid-dev unzip && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /root

# install emane
RUN apt-get update && apt-get install -y libpcap-dev libpcre3-dev libprotobuf-dev libxml2-dev protobuf-compiler unzip uuid-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
WORKDIR /opt
RUN git clone https://github.com/adjacentlink/emane.git
RUN cd emane && \
  ./autogen.sh && \
  ./configure --prefix=/usr && \
  make -j$(nproc)  && \
  make install
RUN ARCH1=$(uname -m | sed -e s/arm64/aarch_64/ | sed -e s/aarch64/aarch_64/) && wget https://github.com/protocolbuffers/protobuf/releases/download/v3.19.6/protoc-3.19.6-linux-$ARCH1.zip && \
  mkdir protoc && \
  unzip protoc-3.19.6-linux-$ARCH1.zip -d protoc
RUN PATH=/opt/protoc/bin:$PATH && \
  cd emane/src/python && \
  make clean && \
  make
RUN /opt/core/venv/bin/python -m pip install emane/src/python

# run daemon
#CMD ["core-daemon"]

# various last minute deps

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  iputils-ping \
  net-tools \
  iproute2 \
  wget \
  curl \
  vim \
  nano \
  mtr \
  tmux \
  iperf \
  git \
  ssh \
  tcpdump \
  docker.io \
  ca-certificates \
  bash \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN git clone https://github.com/gh0st42/core-helpers &&\
  cp core-helpers/bin/* /usr/local/bin &&\
  rm -rf core-helpers

# enable sshd
RUN mkdir /var/run/sshd &&  sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/' /etc/ssh/sshd_config && \
  sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV PASSWORD "netsim"
RUN echo "root:$PASSWORD" | chpasswd

ENV SSHKEY ""

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

RUN mkdir -p /root/.core/myservices && mkdir -p /root/.coregui/custom_services
RUN sed -i 's/grpcaddress = localhost/grpcaddress = 0.0.0.0/g' /etc/core/core.conf

COPY update-custom-services.sh /update-custom-services.sh

EXPOSE 22
EXPOSE 50051


# ADD extra /extra
VOLUME /shared

COPY entryPoint.sh /root/entryPoint.sh
ENTRYPOINT "/root/entryPoint.sh"
