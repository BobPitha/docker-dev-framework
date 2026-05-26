# Declare Makefile targets as .PHONY to avoid accidental collision with a real filename
.PHONY: prepare-ddf-hooks show-ddf-hooks clean-ddf-hooks validate-ddf-hooks build base dev-core dev-tooling dev-gui dev prod clean clean-all help
.DEFAULT_GOAL := build

# Default stage for bare 'make'
STAGE ?= dev-gui

CACHE_OPTION ?=
NO_CACHE ?= 0
PLAIN_PROGRESS ?= 0

ifeq ($(NO_CACHE),1)
CACHE_OPTION := --no-cache
else
CACHE_OPTION :=
endif

ifeq ($(PLAIN_PROGRESS),1)
PROGRESS_OPTION := --progress=plain
else
PROGRESS_OPTION :=
endif

# Derive suffix: dev-* -> "dev", else -> stage name
TAG_SUFFIX = $(if $(filter dev-%,$(STAGE)),dev,$(STAGE))

# Derive banner (uppercase, hyphens to spaces)
BANNER_MSG = $(shell echo $(STAGE) | tr '[:lower:]-' '[:upper:] ')

IS_GIT_DIR := $(shell if git rev-parse --git-dir > /dev/null 2>&1 ; then echo yes ; else echo no ; fi)
REPOSITORY_ROOT := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --show-toplevel ; else dirname $(realpath $(firstword $(MAKEFILE_LIST))) ; fi)

PROJECT_ENV := $(REPOSITORY_ROOT)/workspace-config/workspace.env
ifneq ("$(wildcard $(PROJECT_ENV))","")
include $(PROJECT_ENV)
export
endif

VERSION := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse --short HEAD ; else echo local ; fi)
VERSION_LONG := $(shell if [ "$(IS_GIT_DIR)" = "yes" ] ; then git rev-parse HEAD ; else echo local ; fi)

DOCKER_ROOT_IMAGE ?= ubuntu:noble
ORGANIZATION ?= $(shell id -un)
WORKSPACE_NAME ?= $(notdir $(REPOSITORY_ROOT))
SERVER_USER ?= $(shell id -un)

DOCKER_IMAGE_TAG_ROOT := ${ORGANIZATION}/${WORKSPACE_NAME}_img
DOCKER_CONTAINER_NAME_ROOT := ${WORKSPACE_NAME}
DOCKERFILE := Dockerfile

DOCKER_BUILDKIT ?= 1
export DOCKER_BUILDKIT

prepare-ddf-libs:
	bin/collect-ddf-libs.sh

prepare-ddf-hooks:
	bin/collect-ddf-hooks.sh

prepare-ddf: prepare-ddf-hooks prepare-ddf-libs

show-ddf-hooks: prepare-ddf
	find .generated/ddf-build-hooks -type f | sort
	@echo
	@find .generated/ddf-build-hooks -name manifest.tsv -print -exec cat {} \;

clean-ddf-hooks:
	rm -rf .generated/ddf-build-hooks

clean-ddf-libs:
	rm -rf .generated/ddf-libs

clean-ddf-generated: clean-ddf-hooks clean-ddf-libs

validate-ddf-hooks: prepare-ddf
	@find .generated/ddf-build-hooks -type f -name '*.sh' -print0 | xargs -0 -r bash -n

# Single build recipe
build: validate-ddf-hooks
ifeq ($(DRY_RUN),1)
	@echo "DRY_RUN=1: skipping docker build"
	@find .generated/ddf-build-hooks -type f | sort
else
	bin/banner Docker *$(BANNER_MSG)* build ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:v${VERSION}
	docker build \
		${PROGRESS_OPTION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:v${VERSION} \
		-t ${DOCKER_IMAGE_TAG_ROOT}-${TAG_SUFFIX}:latest \
		--target $(STAGE) \
		--build-arg FROM_IMAGE="${DOCKER_ROOT_IMAGE}" \
		--build-arg SERVER_USER="${SERVER_USER}" \
		--build-arg ORGANIZATION="${ORGANIZATION}" \
		--build-arg VERSION="${VERSION_LONG}" \
		${CACHE_OPTION} \
		-f ${DOCKERFILE} .
endif

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
		| xargs -r docker rmi 2>/dev/null || true
	@echo "Done."

help:
	@echo "DDF Makefile targets:"
	@echo "  show-ddf-hooks     - Generate and list collected DDF hooks"
	@echo "  validate-ddf-hooks - Syntax-check collected hook scripts"
	@echo "  clean-ddf-hooks    - Remove generated DDF hook files"
	@echo "  build       - Build default stage (default: dev-gui)"
	@echo "  base        - Build base stage only"
	@echo "  dev-core    - Build up to dev-core stage"
	@echo "  dev-tooling - Build up to dev-tooling stage"
	@echo "  dev-gui     - Build full GUI dev image"
	@echo "  dev         - Build full dev image (dev-gui stage)"
	@echo "  prod        - Build production image (placeholder)"
	@echo "  clean       - Remove locally built images"
	@echo ""
	@echo "Variables:"
	@echo "  DRY_RUN=1          - Generate hooks but skip docker build"
	@echo "  NO_CACHE=1         - Disable Docker build cache"
	@echo "  PLAIN_PROGRESS=1   - Use plain progress output for Docker build"
	@echo "  DOCKER_ROOT_IMAGE  - Base image (default: ubuntu:noble)"
	@echo "  ORGANIZATION       - Docker org/user (default: current user)"
	@echo "  PROJECT            - Project name (default: repo basename)"
	@echo "  SERVER_USER        - Container username (default: current user)"