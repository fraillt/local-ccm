SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: all validate .docker-build render release-artifacts chart-package chart-push image-build image-push clean

ORIGIN_URL := $(shell git remote get-url origin 2>/dev/null)
DEFAULT_REPOSITORY_OWNER := $(shell printf '%s\n' "$(ORIGIN_URL)" | sed -nE 's#.*github\.com[:/]([^/]+)/[^/]+(\.git)?$$#\1#p')

REPOSITORY_OWNER ?= $(or $(REGISTRY_OWNER),$(DEFAULT_REPOSITORY_OWNER))
REGISTRY ?= $(if $(strip $(REPOSITORY_OWNER)),ghcr.io/$(REPOSITORY_OWNER),)
IMAGE_REPOSITORY ?= $(if $(strip $(REGISTRY)),$(REGISTRY)/local-ccm,)
CHART_REPOSITORY ?= $(if $(strip $(REPOSITORY_OWNER)),oci://ghcr.io/$(REPOSITORY_OWNER)/charts,)

TAG ?= latest
RELEASE_VERSION ?= $(TAG)
PLATFORM ?= linux/amd64
PUSH_PLATFORMS ?= linux/amd64,linux/arm64
VALIDATE_PLATFORM ?= linux/amd64
LOAD ?= 1
CACHE_FROM ?=
CACHE_TO ?= type=inline

BUILD_DIR ?= $(CURDIR)/build
RENDER_DIR ?= $(BUILD_DIR)/templates
ARTIFACTS_DIR ?= $(BUILD_DIR)/artifacts
HELM_PACKAGE_DIR ?= $(BUILD_DIR)/helm-package

define require_var
if [[ -z "$($1)" ]]; then \
  echo "$1 is required" >&2; \
  exit 1; \
fi
endef

all: validate

validate:
	go test ./...
	go build ./...
	helm lint templates/charts/local-ccm
	$(MAKE) .docker-build \
		IMAGE_TAG=local-ccm:validate \
		PLATFORM=$(VALIDATE_PLATFORM) \
		PUSH_IMAGE=0 \
		LOAD_IMAGE=0

.docker-build:
	@$(call require_var,IMAGE_TAG)
	docker buildx build . \
		--tag $(IMAGE_TAG) \
		$(if $(strip $(CACHE_FROM)),--cache-from $(CACHE_FROM)) \
		$(if $(strip $(CACHE_TO)),--cache-to $(CACHE_TO)) \
		$(if $(strip $(PLATFORM)),--platform=$(PLATFORM)) \
		--provenance=false \
		--push=$(PUSH_IMAGE) \
		--load=$(LOAD_IMAGE)

render:
	@$(call require_var,RELEASE_VERSION)
	@$(call require_var,REPOSITORY_OWNER)
	rm -rf "$(RENDER_DIR)"
	RELEASE_VERSION="$(RELEASE_VERSION)" \
	REPOSITORY_OWNER="$(REPOSITORY_OWNER)" \
	OUT_DIR="$(RENDER_DIR)" \
	bash scripts/render-templates.sh

release-artifacts: render
	mkdir -p "$(ARTIFACTS_DIR)"
	cp "$(RENDER_DIR)/static/local-ccm.yaml" "$(ARTIFACTS_DIR)/local-ccm.yaml"
	cp "$(RENDER_DIR)/static/node-lifecycle-controller.yaml" "$(ARTIFACTS_DIR)/node-lifecycle-controller.yaml"

chart-package: render
	@$(call require_var,RELEASE_VERSION)
	rm -rf "$(HELM_PACKAGE_DIR)"
	mkdir -p "$(HELM_PACKAGE_DIR)"
	helm package \
		"$(RENDER_DIR)/charts/local-ccm" \
		--destination "$(HELM_PACKAGE_DIR)" \
		--version "$(RELEASE_VERSION)"

chart-push: chart-package
	@$(call require_var,CHART_REPOSITORY)
	helm push "$(HELM_PACKAGE_DIR)/local-ccm-$(RELEASE_VERSION).tgz" "$(CHART_REPOSITORY)"

image-build:
	@$(call require_var,IMAGE_REPOSITORY)
	$(MAKE) .docker-build \
		IMAGE_TAG=$(IMAGE_REPOSITORY):$(TAG) \
		PLATFORM=$(PLATFORM) \
		PUSH_IMAGE=0 \
		LOAD_IMAGE=$(LOAD)

image-push:
	@$(call require_var,IMAGE_REPOSITORY)
	$(MAKE) .docker-build \
		IMAGE_TAG=$(IMAGE_REPOSITORY):$(TAG) \
		PLATFORM=$(PUSH_PLATFORMS) \
		PUSH_IMAGE=1 \
		LOAD_IMAGE=0

clean:
	rm -rf "$(BUILD_DIR)"
