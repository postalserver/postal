# ==============================================================================
# Welcome to the Makefile
# ==============================================================================
#
# This Makefile contains a series of tasks which can help with building, testing
# and working with the app. The following tasks are available to you:
#
# Image building & releasing actions:
#
#   make docker-build      - Builds a production Docker image.
#   make docker-ci-build   - Builds an image without any asset compilation,
#                            ideal for running test suites and similar tasks.
#   make docker-image      - Builds a production Docker image and tags it as
#                            appropriate based on the current branch & tag.
#   make docker-release    - Builds a production Docker image and uploads to the
#                            registry.
#

# ==============================================================================
# Configuration
# ==============================================================================

# Docker image name to release the production image as.
DOCKER_IMAGE := ghcr.io/postalserver/postal

# Path to bundle config
BUNDLE_CONFIG ?= $(HOME)/.bundle/config

# Detect if a tty is available
TTY := $(shell [ -t 0 ] && echo 1)

# Tag names
DOCKER_TAG_NAME ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
DOCKER_TAG_VERSION ?= $(shell git describe --tags --exact-match 2>/dev/null)

ifeq ($(DOCKER_TAG_NAME),master)
	DOCKER_TAG_NAME = latest
endif

ifeq ($(DOCKER_TAG_NAME),main)
	DOCKER_TAG_NAME = latest
endif

# Version string to use
VERSION ?= $(DOCKER_TAG_VERSION)
ifeq ($(VERSION),)
	VERSION = $(shell git describe --tags 2>/dev/null)
endif

ifeq ($(VERSION),)
	VERSION = 0.0.0-dev
endif

# ==============================================================================
# Image Building
# ==============================================================================

DOCKER_BUILD_CMD = DOCKER_BUILDKIT=1 docker \
	build $(if $(TTY),,--progress plain) \
	--build-arg VERSION=$(VERSION) \
	.

DOCKER_CI_BUILD_CMD = $(DOCKER_BUILD_CMD) --target=ci

.PHONY: docker-build
docker-build:
	$(DOCKER_BUILD_CMD)

.PHONY: docker-ci-build
docker-ci-build:
	$(DOCKER_CI_BUILD_CMD)

# ==============================================================================
# Image Tagging
# ==============================================================================

.PHONY: docker-image
docker-image: docker-build
	$(eval IMAGE := $(shell $(DOCKER_BUILD_CMD) -q))
ifeq ($(DOCKER_TAG_NAME),latest)
	docker tag "$(IMAGE)" "$(DOCKER_IMAGE):$(DOCKER_TAG_NAME)"
endif

# ==============================================================================
# Image Releasing
# ==============================================================================

.PHONY: docker-release
docker-release: docker-image
ifeq ($(DOCKER_TAG_NAME),latest)
	docker push "$(DOCKER_IMAGE):$(DOCKER_TAG_NAME)"
endif
ifneq ($(DOCKER_TAG_VERSION),)
	docker tag "$(DOCKER_IMAGE):$(DOCKER_TAG_NAME)" \
		"$(DOCKER_IMAGE):$(DOCKER_TAG_VERSION)" && \
		docker push "$(DOCKER_IMAGE):$(DOCKER_TAG_VERSION)"
endif

# ==============================================================================
# Tests
# ==============================================================================

.PHONY: ci-test
ci-test: docker-ci-build
	$(eval IMAGE := $(shell $(DOCKER_CI_BUILD_CMD) -q))
	$(eval RAND := $(shell echo "$${RANDOM}$$(date +%s)"))
	POSTAL_IMAGE=$(IMAGE) \
	docker-compose -p "postal$(RAND)" run --rm postal sh -c 'bundle exec rspec'; \
	EXIT_CODE=$$?; \
	docker-compose -p "postal$(RAND)" down -v; \
	exit $$EXIT_CODE

.PHONY: test
test:
	bundle exec rspec
