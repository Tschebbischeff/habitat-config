#!/usr/bin/env bash

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

[ -n "$pushAfterBuild" ] && [ -z "$repositoryNamespace" ] && { echo "When pushing a repository name must be supplied."; exit 1; }

currentVersion="$(cat ./metadata.json | jq -r '.version')"
currentVersionMaj="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)')"
currentVersionMajMin="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"
currentVersionMajMinPat="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"

docker buildx create \
    --use \
    --name habitat-config-builder \
    node-amd64
docker buildx create \
    --append \
    --name habitat-config-builder \
    node-arm64

docker build \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMinPat" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMin" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMaj" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:latest" \
    --platform linux/amd64,linux/arm64 \
    "$([ -n "$pushAfterBuild" ] && echo "--push")" \
    ./habitat-config

docker buildx stop habitat-config-builder