# IS_GIT_DIR := $(shell if git rev-parse --git-dir > /dev/null 2>&1 ; then echo yes ; else echo no ; fi )
# REPOSITORY_ROOT := $$( if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse --show-toplevel ; else dirname $$(realpath $(firstword $(MAKEFILE_LIST))) ; fi )
# VERSION := $(shell if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse --short HEAD ; else echo local ; fi )
# VERSION_LONG := $(shell if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse HEAD ; else echo local ; fi )

# DOCKER_ROOT_IMAGE := ubuntu:focal
# ORGANIZATION := bob
# PROJECT := bwc2
# DOCKER_IMAGE_TAG_ROOT := ${ORGANIZATION}/${PROJECT}_img
# DOCKER_CONTAINER_NAME_ROOT := ${PROJECT}
# SERVER_USER := bob
# DOCKERFILE := Dockerfile


IS_GIT_DIR := $(shell if git rev-parse --git-dir > /dev/null 2>&1 ; then echo yes ; else echo no ; fi)
REPOSITORY_ROOT := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --show-toplevel ; else dirname $(realpath $(firstword $(MAKEFILE_LIST))) ; fi)

PROJECT_ENV := $(REPOSITORY_ROOT)/workspace-config/project.env
ifneq ("$(wildcard $(PROJECT_ENV))","")
include $(PROJECT_ENV)
export
endif

VERSION := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --short HEAD ; else echo local ; fi)
VERSION_LONG := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse HEAD ; else echo local ; fi)

DOCKER_ROOT_IMAGE ?= ubuntu:focal
ORGANIZATION ?= $(shell id -un)
PROJECT ?= $(notdir $(REPOSITORY_ROOT))
SERVER_USER ?= $(shell id -un)

DOCKER_IMAGE_TAG_ROOT := ${ORGANIZATION}/${PROJECT}_img
DOCKER_CONTAINER_NAME_ROOT := ${PROJECT}
DOCKERFILE := Dockerfile


DOCKER_RUN_USER_ARGS := ${DOCKER_RUN_USER_ARGS} \
			--volume=${REPOSITORY_ROOT}/shell_state/Code:/home/${SERVER_USER}/.config/Code \
			--volume=${HOME}/.ssh:/home/${SERVER_USER}/.ssh

build: dev

base:
	bin/banner Docker *BASE* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-base:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-base:latest \
		--target base \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

dev-core:
	bin/banner Docker *DEVELOPMENT* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:latest \
		--target dev-core \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

dev-tooling:
	bin/banner Docker *DEVELOPMENT* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:latest \
		--target dev-tooling \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

dev:
	bin/banner Docker *DEVELOPMENT* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:latest \
		--target dev-gui \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

dev-obsolete:
	bin/banner Docker *DEVELOPMENT* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-dev:latest \
		--target dev-obsolete \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

prod:
	bin/banner Docker *PRODUCTION* build ${DOCKER_IMAGE_TAG_ROOT}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-prod:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-prod:latest \
		--target prod \
		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
		--build-arg SERVER_USER=${SERVER_USER} \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .
