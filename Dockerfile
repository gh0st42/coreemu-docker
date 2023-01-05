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
  apt-get install -y git sudo wget tzdata python3 python3-pip python3-venv 
#&& \
# apt-get clean && \
# rm -rf /var/lib/apt/lists/*

# install core
WORKDIR /opt
RUN git clone https://github.com/coreemu/core
WORKDIR /opt/core
RUN git checkout ${BRANCH}
RUN NO_SYSTEM=1 ./setup.sh
RUN . /root/.bashrc && inv install -v -p ${PREFIX}
ENV PATH "$PATH:/opt/core/venv/bin"

# install emane
#RUN apt-get install -y libpcap-dev libpcre3-dev libprotobuf-dev libxml2-dev protobuf-compiler uuid-dev && \
RUN apt-get install -y libpcap-dev libpcre3-dev libxml2-dev uuid-dev unzip && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /root
ENV PB_REL="https://github.com/protocolbuffers/protobuf/releases"
#RUN wget $PB_REL/download/v21.12/protoc-21.12-linux-aarch_64.zip && \
#  unzip protoc-21.12-linux-aarch_64.zip -d /usr/local
RUN wget $PB_REL/download/v21.12/protobuf-all-21.12.tar.gz && \
  tar xf protobuf-all-21.12.tar.gz && \
  cd protobuf-21.12 && \
  ./autogen.sh && ./configure && make -j$(nproc) && make install && ldconfig

WORKDIR /opt
RUN git clone https://github.com/adjacentlink/emane.git
RUN cd emane && \
  ./autogen.sh && \
  ./configure --prefix=/usr && \
  make -j$(nproc)  && \
  make install
RUN /opt/core/venv/bin/python -m pip install emane/src/python
RUN wget https://raw.githubusercontent.com/protocolbuffers/protobuf/main/python/google/protobuf/internal/builder.py -O /opt/core/venv/lib/python3.10/site-packages/google/protobuf/internal/builder.py

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
