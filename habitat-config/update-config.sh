#!/usr/bin/env bash

cd "/habitat-config" || exit 1

for dirPath in "./source/"*; do
    moduleName="$(basename "$dirPath")"
    echo "*** Applying configuration for module '$moduleName' (Source directory: /habitat-config/source/$moduleName)..."
    # Traefik Dynamic Config
    if [ -d "./target/traefik" ]; then
        echo "Traefik config:"
        for f in "./target/traefik/"*; do
            filename=$(basename -- "$f")
            filename="${filename%.*}"
            [[ "$filename" == *".$moduleName" ]] && rm -f "$f"
        done
        if [ -d "$dirPath/traefik" ]; then
            for f in "$dirPath/traefik/"*; do
                filename=$(basename -- "$f")
                extension="${filename##*.}"
                filename="${filename%.*}"
                echo " $f -> ./target/traefik/$filename.$moduleName.$extension"
                cp -f "$f" "./target/traefik/$filename.$moduleName.$extension";
            done
        else
            echo " None"
        fi
    fi
done