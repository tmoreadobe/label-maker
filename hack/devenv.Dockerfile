#
# Copyright 2020 Alexander Vollschwitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM golang:1.13.6-buster@sha256:f6cefbdd25f9a66ec7dcef1ee5deb417882b9db9629a724af8a332fe54e3f7b3

LABEL maintainer "vollschwitz@gmx.net"

# general env settings
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=yes

# kubectl
ARG KUBE_PKG_VERSION="1.16.8-00"

# tool versions

ARG OPSDK_VERSION="0.15.2"

#
# Add a standard, non-root user based on USER_ID and GROUP_ID passed as build
# arguments. This user will be mapped to the host user invoking the development
# container.
#
#	https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
#
# Also, create docker group and add standard user to it.
#
ARG USER_ID
ARG GROUP_ID
ARG DOCKER_GROUP_ID

RUN groupadd -g 200 go && \
    useradd -l -u ${USER_ID:-1000} -g go go && \
    install -d -m 0755 -o go -g go /home/go && \
    groupadd -g 1001 docker && \
    usermod -aG docker go
RUN chown -R go:go /go
# install required packages
RUN \
    apt-get update && \
    apt-get upgrade -y --fix-missing && \
    apt-get install -y --no-install-recommends --fix-missing \
        jq \
        vim \
        unzip \
        tree \
        dnsutils \
        software-properties-common

# tools installed via additional package sources

#
# Docker
#
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey && \
    apt-key add /tmp/dkey && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
		$(lsb_release -cs) \
		stable" && \
	apt-get update && apt-get -y install docker-ce-cli

#
# kubectl
#
# TODO: currently, only Xenial packages are available; switch to
#        Bionic once released
RUN curl -s -L https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
        kubectl=$KUBE_PKG_VERSION

RUN apt-get clean -y && \
    rm -rf \
        /var/cache/debconf/* \
        /var/lib/apt/lists/* \
        /var/log/* \
        /tmp/* \
        /var/tmp/*

# directly installed tools, i.e. not using OS' package manager

# Operator SDK
ARG OPSDK_URL="https://github.com/operator-framework/operator-sdk/releases/download/v${OPSDK_VERSION}/operator-sdk-v${OPSDK_VERSION}-x86_64-linux-gnu"
ARG OPSDK_ASC_URL="https://github.com/operator-framework/operator-sdk/releases/download/v${OPSDK_VERSION}/operator-sdk-v${OPSDK_VERSION}-x86_64-linux-gnu.asc"
RUN curl -fsSL "${OPSDK_URL}" -o operator-sdk && \
	curl -fsSL "${OPSDK_ASC_URL}" -o operator-sdk.asc && \
	gpg --keyserver keyserver.ubuntu.com \
		--recv-key "A75BBA1528FE0D8E3C6AE5086B1D07CB9391EA2A" && \
	gpg --verify operator-sdk.asc && \
	mv operator-sdk /usr/local/bin/operator-sdk && \
	chmod +x /usr/local/bin/operator-sdk && \
	rm operator-sdk.asc

USER go
