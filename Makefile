.PHONY: image all

# Prefer the GitHub owner from the origin remote so forks publish to their own
# GHCR namespace. Override with REGISTRY_OWNER=<owner> or REGISTRY=<registry>.
ORIGIN_URL := $(shell git remote get-url origin 2>/dev/null)
REGISTRY_OWNER ?= $(shell printf '%s\n' "$(ORIGIN_URL)" | sed -nE 's#.*github\.com[:/]([^/]+)/[^/]+(\.git)?$$#\1#p')
REGISTRY ?= $(if $(strip $(REGISTRY_OWNER)),ghcr.io/$(REGISTRY_OWNER),)
ifeq ($(strip $(REGISTRY)),)
$(error Set REGISTRY or REGISTRY_OWNER; could not infer GitHub owner from origin remote)
endif
TAG ?= latest
PUSH ?= 1
LOAD ?= 0
PLATFORM ?= linux/amd64,linux/arm64

BUILDX_ARGS := --provenance=false --push=$(PUSH) --load=$(LOAD) \
  --cache-to type=inline \
  $(if $(strip $(PLATFORM)),--platform=$(PLATFORM))

# Build image
image:
	docker buildx build . \
		--tag $(REGISTRY)/local-ccm:$(TAG) \
		--cache-from type=registry,ref=$(REGISTRY)/local-ccm:latest \
		$(BUILDX_ARGS)
	export REPOSITORY="$(REGISTRY)/local-ccm" && \
	export TAG="$(TAG)" && \
	export IMAGE="$(REGISTRY)/local-ccm:$(TAG)" && \
	yq -i '.image.repository = strenv(REPOSITORY)' templates/charts/local-ccm/values.yaml && \
	yq -i '.image.tag = strenv(TAG)' templates/charts/local-ccm/values.yaml && \
	yq -i '.nodeLifecycleController.image.repository = strenv(REPOSITORY)' templates/charts/local-ccm/values.yaml && \
	yq -i '.nodeLifecycleController.image.tag = strenv(TAG)' templates/charts/local-ccm/values.yaml && \
	yq -i '.spec.template.spec.containers[0].image = strenv(IMAGE)' templates/static/local-ccm.yaml && \
	yq -i '.spec.template.spec.containers[0].image = strenv(IMAGE)' templates/static/node-lifecycle-controller.yaml
