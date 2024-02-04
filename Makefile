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

.DEFAULT_GOAL := help
SHELL = /bin/bash

##
# You need to set the following parameters in configuration file ${DIM}.makerc${NRM}, with every
# line containing a parameter in the form ${ITL}key = value${NRM}:
#
#	${ITL}REGISTRY${NRM}	the ${ITL}Docker${NRM} registry to use for built images
#
#	${ITL}REPO${NRM}		the repository to use inside ${ITL}REGISTRY${NRM}
#
-include .makerc

#
#

BUILD_OUTPUT=build/_output
BINARIES=$(BUILD_OUTPUT)/bin
CONTAINER_PREFIX=label-maker
CONTAINER_IMAGE=label-maker-devenv
GO_PREAMBLE=CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GIT_TERMINAL_PROMPT=1
REGISTRY=tushar8408
REPO=label-maker
#${ITL}VERBOSE=y${NRM}
##
# You can set the following environment variables when calling make:
#
#	${ITL}VERBOSE=y${NRM}	get detailed output
#
#	${ITL}ISOLATED=y${NRM}	when using this with a build target, the build will be
#			fully isolated: local caches such as ${DIM}\${GOPATH}/pkg${NRM} and
#			${DIM}~/.cache${NRM} will not be mounted into the development
#			container. This forces a full build, where all
#			dependencies are retrieved & built inside the
#			container, and discarded with the container when
#			it exits.
#

VERBOSE ?=
ifeq ($(VERBOSE),y)
    $(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
    $(warning ***** $(shell date))
    MAKEFLAGS += --trace
else
    MAKEFLAGS += -s
endif

#ISOLATED ?=
#ifeq ($(ISOLATED),y)
CACHE_VOLS=
#else
#    CACHE_VOLS=-v ${GOPATH}/pkg:/go/pkg -v /home/${USER}/.cache:/home/go/.cache
#endif

#
# If DOCKERIZE is not set, we set it to 'y' to flag that Dockerization is
# necessary. For goals where this is applicable, make is then re-entered inside
# the development container with the *original* goals that were given to make on
# the command line. All applicable goals need to be registered for Dockerization
# further below.
#
# Note: You cannot use a Dockerized target as a dependency, e.g using a
#       Dockerized 'build' target, the following won't work:
#
#       	all: build report
#
#       This is because make would be re-entered inside the container with goal
#       'all', not 'build'.
#
DOCKERIZE ?= y

export

###
#
# This section contains goals that are not directly Dockerized (but may have
# dependencies that are)
#

.PHONY: help
help:
#	show this help
#
	$(call utils, synopsis) | more


.PHONY: sane-registry
sane-registry: #
	$(call utils, ensure_defined REGISTRY $(REGISTRY))
	$(call utils, ensure_defined REPO $(REPO))


.PHONY: devenv
devenv:
#	build the development environment container image
	$(call utils, build_image "$(CONTAINER_IMAGE)" hack/devenv.Dockerfile)


.PHONY: clean
clean:
#	clean-up built binaries
#
	rm -rf $(BUILD_OUTPUT)/*


#
# This section contains goals that are run Dockerized.
#

ifeq ($(DOCKERIZE),y)

push rmi opsdk-gen build bin ctrlup shell: dockerize

else

.PHONY: bin
bin:
#	build ${ITL}label-maker${NRM} controller binary directly, without using ${ITL}Operator SDK${NRM}
#
	$(GO_PREAMBLE) go build -o $(BINARIES)/label-maker cmd/manager/main.go


.PHONY: build
build: sane-registry
#	build ${ITL}label-maker${NRM} controller (binary & container image) using ${ITL}Operator SDK${NRM}
#
	$(GO_PREAMBLE) operator-sdk build $(REGISTRY)/$(REPO)/label-maker


.PHONY: push
push: sane-registry
#	push ${ITL}label-maker${NRM} container image to registry
#
	docker push $(REGISTRY)/$(REPO)/label-maker


.PHONY: rmi
rmi: sane-registry
#	remove ${ITL}label-maker${NRM} container image locally
#
	docker rmi -f $(REGISTRY)/$(REPO)/label-maker


.PHONY: ctrlup
ctrlup:
#	run the controller locally
#
	$(GO_PREAMBLE) OPERATOR_NAME=label-maker POD_NAMESPACE=kube-system \
		ROLE_LABEL="node.kubernetes.io/role" \
			operator-sdk up local --namespace="" 2>&1


.PHONY: opsdk-gen
opsdk-gen:
#	run ${ITL}operator-sdk generate${NRM}
#
	$(GO_PREAMBLE) operator-sdk generate k8s
	$(GO_PREAMBLE) operator-sdk generate openapi


.PHONY: shell
shell:
#	start an interactive session in the development environment container
#
	bash


#
# end of Dockerized goals
#
endif

#
# run goals inside development container
#
.PHONY: dockerize
dockerize: #
	$(call utils, start_devenv_container "$(MAKECMDGOALS)")

#
# helper functions
#
utils = ./hack/devenvutil $(1)
