# Declare Makefile targets as .PHONY to avoid accidental collision with a real filename
.PHONY: build base dev-core dev-tooling dev-gui dev prod clean clean-all help
.DEFAULT_GOAL := build

# Default stage for bare 'make'
STAGE ?= dev-gui

# Derive suffix: dev-* -> "dev", else -> stage name
TAG_SUFFIX = $(STAGE)

# Derive banner (uppercase, hyphens to spaces)
BANNER_MSG = $(shell echo $(STAGE) | tr '[:lower:]-' '[:upper:] ')

IS_GIT_DIR := $(shell if git rev-parse --git-dir > /dev/null 2>&1 ; then echo yes ; else echo no ; fi)
REPOSITORY_ROOT := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --show-toplevel ; else dirname $(realpath $(firstword $(MAKEFILE_LIST))) ; fi)

PROJECT_ENV := $(REPOSITORY_ROOT)/workspace-config/project.env
ifneq ("$(wildcard $(PROJECT_ENV))","")
include $(PROJECT_ENV)
export
endif

VERSION := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --short HEAD ; else echo local ; fi)
VERSION_LONG := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse HEAD ; else echo local ; fi)

DOCKER_ROOT_IMAGE ?= ubuntu:noble
ORGANIZATION ?= $(shell id -un)
PROJECT ?= $(notdir $(REPOSITORY_ROOT))
SERVER_USER ?= $(shell id -un)

DOCKER_IMAGE_TAG_ROOT := ${ORGANIZATION}/${PROJECT}_img
DOCKER_CONTAINER_NAME_ROOT := ${PROJECT}
DOCKERFILE := Dockerfile

# Single build recipe
build:
	bin/banner Docker *$(BANNER_MSG)* build ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:v${VERSION}
	docker build \
		-t ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:latest \
		--target $(STAGE) \
		--build-arg FROM_IMAGE="${DOCKER_ROOT_IMAGE}" \
		--build-arg SERVER_USER="${SERVER_USER}" \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .

base: STAGE = base
base: build

dev-core: STAGE = dev-core
dev-core: build

dev-tooling: STAGE = dev-tooling
dev-tooling: build

dev-gui: STAGE = dev-gui
dev-gui: build

dev: STAGE = dev-gui
dev: build

prod: STAGE = prod
prod: build

# Clean only the current version's images
clean:
	@for suffix in base dev prod; do \
		echo "Cleaning ${DOCKER_IMAGE_TAG_ROOT}-$$suffix:v${VERSION}"; \
		docker rmi ${DOCKER_IMAGE_TAG_ROOT}-$$suffix:v${VERSION} 2>/dev/null || true; \
		docker rmi ${DOCKER_IMAGE_TAG_ROOT}-$$suffix:latest 2>/dev/null || true; \
	done

# Remove ALL locally built images for this project
clean-all:
	@echo "Removing all locally built ${DOCKER_IMAGE_TAG_ROOT} images..."
	@docker images --format '{{.Repository}}:{{.Tag}}' \
		| grep '^${DOCKER_IMAGE_TAG_ROOT}' \
		| xargs -r docker rmi 2>/dev/null || true \
	@echo "Done."

help:
	@echo "DDF Makefile targets:"
	@echo "  build       - Build dev image (default)"
	@echo "  base        - Build base stage only"
	@echo "  dev-core    - Build up to dev-core stage"
	@echo "  dev-tooling - Build up to dev-tooling stage"  
	@echo "  dev         - Build full dev image (dev-gui stage)"
	@echo "  prod        - Build production image (placeholder)"
	@echo "  clean       - Remove locally built images"
	@echo ""
	@echo "Variables:"
	@echo "  DOCKER_ROOT_IMAGE  - Base image (default: ubuntu:noble)"
	@echo "  ORGANIZATION       - Docker org/user (default: current user)"
	@echo "  PROJECT            - Project name (default: repo basename)"
	@echo "  SERVER_USER        - Container username (default: current user)"