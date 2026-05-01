#!/usr/bin/env bash

repositoryNamespace=""
pushAfterBuild=""
while [ "$#" -gt "0" ]; do
    [ "$1" == "--" ] && shift && break
    [ "$1" == "--push" ] && pushAfterBuild="_"
    # Positional arguments
    if [[ ! ( "$1" =~ ^-.* ) ]]; then
        { [ -z "$repositoryNamespace" ] && { repositoryNamespace="$1"; true; } } ||
        { :; }
    fi
    shift
done

currentVersion="$(cat ./metadata.json | jq -r '.version')"
currentVersionMaj="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)')"
currentVersionMajMin="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"
currentVersionMajMinPat="$(echo "$currentVersion" | grep -Po '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')"

docker build \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMinPat" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMajMin" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:$currentVersionMaj" \
    -t "$([ -n "$repositoryNamespace" ] && echo "$repositoryNamespace/")habitat-config:latest" \
    "$([ -n "$pushAfterBuild" ] && echo "--push")" \
    ./habitat-config