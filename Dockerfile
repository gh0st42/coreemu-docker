# syntax=docker/dockerfile:1
FROM ubuntu:22.04
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

# install core
WORKDIR /opt
RUN git clone https://github.com/coreemu/core
WORKDIR /opt/core
RUN git checkout ${BRANCH}
RUN NO_SYSTEM=1 ./setup.sh
RUN . /root/.bashrc && inv install -v -p ${PREFIX}
ENV PATH "$PATH:/opt/core/venv/bin"

# install emane
RUN apt-get install -y libpcap-dev libpcre3-dev libprotobuf-dev libxml2-dev protobuf-compiler uuid-dev
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
CMD ["core-daemon"]

