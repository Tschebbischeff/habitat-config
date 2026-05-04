#!/usr/bin/env bash

PLATFORMS="linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64,linux/386,linux/ppc64le,linux/riscv64,linux/s390x"

repositoryNamespace=""
pushAfterBuild="_"
while [ "$#" -gt "0" ]; do
    [ "$1" == "--" ] && shift && break
    [ "$1" == "--no-push" ] && pushAfterBuild=""
    # Positional arguments
    if [[ ! ( "$1" =~ ^-.* ) ]]; then
        { [ -z "$repositoryNamespace" ] && { repositoryNamespace="$1"; true; } } ||
        { :; }
    fi
    shift
done

[ "$pushAfterBuild" ] && [ -z "$repositoryNamespace" ] && { echo "When pushing a repository name must be supplied."; exit 1; }

currentVersion="$(cat ./metadata.json | jq -r '.version')"
currentVersionMaj="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)')"
currentVersionMajMin="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"
currentVersionMajMinPat="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"

# docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx create \
    --use --bootstrap \
    --driver docker-container \
    --name habitat-config-builder

docker buildx build \
    -t "$([ "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMinPat" \
    -t "$([ "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMin" \
    -t "$([ "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMaj" \
    -t "$([ "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:latest" \
    --platform "$PLATFORMS" \
    --builder habitat-config-builder \
    "$([ "$pushAfterBuild" ] && echo "--push")" \
    ./habitat-config

docker buildx stop habitat-config-builder
docker buildx rm habitat-config-builder