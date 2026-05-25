#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

TEMPLATES_DIR=${TEMPLATES_DIR:-"${REPO_ROOT}/templates"}
OUT_DIR=${OUT_DIR:-"${REPO_ROOT}/build/rendered"}
RELEASE_VERSION=${RELEASE_VERSION:-}
REPOSITORY_OWNER=${REPOSITORY_OWNER:-}

if [[ -z "${RELEASE_VERSION}" ]]; then
  echo "RELEASE_VERSION is required" >&2
  exit 1
fi

if [[ -z "${REPOSITORY_OWNER}" ]]; then
  echo "REPOSITORY_OWNER is required" >&2
  exit 1
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
cp -R "${TEMPLATES_DIR}/." "${OUT_DIR}/"

while IFS= read -r -d '' file; do
  sed -i \
    -e "s|{REPLACE_VERSION}|${RELEASE_VERSION}|g" \
    -e "s|{REPLACE_OWNER}|${REPOSITORY_OWNER}|g" \
    "${file}"
done < <(find "${OUT_DIR}" -type f -print0)