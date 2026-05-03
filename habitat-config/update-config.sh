#!/usr/bin/env bash

# ### Init

cd "/habitat-config" || exit 1

[ -z "${APP_SESSION_ID}" ] && { echo "No APP_SESSION_ID provided, cannot synchronize configuration."; exit 1; }

ORCH_PATH="./orchestration"
ORCH_SESSION_PATH="$ORCH_PATH/${APP_SESSION_ID}"
SRC_PATH="./source"
TGT_PATH="./target"
declare -a CONSUMERS
[ -d "$SRC_PATH/.consume" ] && for filePath in "$SRC_PATH/.consume/"*; do
    fileName="$(basename "$filePath")"
    fileExtension="${fileName##*.}"
    [ "$fileExtension" != "sh" ] && continue
    consumerName="${fileName%.*}"
    CONSUMERS["${#CONSUMERS[@]}"]="$consumerName"
done
IFS="," read -r -a tmp_modules <<< "${APP_MODULES}"
declare -a MODULES
for moduleName in "${tmp_modules[@]}"; do
    MODULES[${#MODULES[@]}]="$(echo "$moduleName" | xargs)"
done

echo "*** Habitat Configuration Sidecar for Module '${APP_MODULE_NAME}'"
echo "Session ID: ${APP_SESSION_ID}"
echo "Modules: ${MODULES[*]}"
{ [ "${#CONSUMERS[@]}" -gt "0" ] && echo "Consumers: ${CONSUMERS[*]}"; } || echo "Consumers: (None)"


# ### Init Orchestration

echo "*** Orchestration"

for dirPath in "$ORCH_PATH"*; do
    [ "$(basename "$dirPath")" != "${APP_SESSION_ID}" ] && rm -rf "$dirPath" 2>/dev/null
done
if [ -d "$ORCH_SESSION_PATH" ] && [ -f "$ORCH_SESSION_PATH/.${APP_MODULE_NAME}.finished" ]; then
    echo "This session has already been configured. Skipping everything and exiting with assumed success."
    exit 0
fi
mkdir -p "$ORCH_SESSION_PATH"

for consumerName in "${CONSUMERS[@]}"; do
    # shellcheck disable=SC2115 # ORCH_SESSION_PATH cannot be empty
    [ -d "$ORCH_SESSION_PATH/$consumerName" ] && rm -rf "$ORCH_SESSION_PATH/$consumerName"
    mkdir -p "$ORCH_SESSION_PATH/$consumerName"
done
touch "$ORCH_SESSION_PATH/.${APP_MODULE_NAME}.started"
echo "Waiting for all modules to start..."
while :; do
    sleep 1
    allStarted="_"
    for moduleName in "${MODULES[@]}"; do
        [ -f "$ORCH_SESSION_PATH/.$moduleName.started" ] || allStarted=""
    done
    [ -n "$allStarted" ] && break
done
echo "All modules started."


# ### Provide Own Configurations

echo "*** Providing configuration..."

anyProviders=""
for serviceSrcPath in "$SRC_PATH/"*; do
    anyProviders="_"
    consumerName="$(basename "$serviceSrcPath")"
    if [ ! -d "$ORCH_SESSION_PATH/$consumerName" ]; then
        echo "No consumers for configuration target '$consumerName', skipping."
        continue
    fi
    echo "Copying configuration for target '$consumerName'..."
    cp -rp "$serviceSrcPath" "$ORCH_SESSION_PATH/$consumerName/${APP_MODULE_NAME}"
    # # Traefik
    # if [ -d "$SRC_PATH/traefik" ]; then
    #     echo "Applying traefik config:"
    #     for f in "./source/traefik/dynamic/"*; do
    #         filename=$(basename -- "$f")
    #         extension="${filename##*.}"
    #         filename="${filename%.*}"
    #         echo " $f -> ./target/traefik/$filename.$moduleName.$extension"
    #         cp -f "$f" "./target/traefik/$filename.$moduleName.$extension";
    #     done
    #     if inArray "traefik" "${#WAIT_ON_TARGETS[@]}"; then
    #     fi
    # else
    #     echo "No traefik config to apply from this module."
    # fi
done
[ -z "$anyProviders" ] && echo "This module does not provide any configuration."
touch "$ORCH_SESSION_PATH/.${APP_MODULE_NAME}.finished"

# ### Merge Configurations on Consumer Side

echo "*** Consuming configuration..."

finalExitCode="0"
if [ "${#CONSUMERS[@]}" -gt "0" ]; then
    echo "Waiting for all modules to finish their providing stage..."
    for moduleName in "${MODULES[@]}"; do
        [ ! -f "$ORCH_SESSION_PATH/.$moduleName.finished" ] && continue
    done
    for consumerName in "${CONSUMERS[@]}"; do
        if [ -z "$(ls -A "$ORCH_SESSION_PATH/$consumerName")" ]; then
            echo "No modules have provided configuration for target '$consumerName', skipping execution of consumer."
        fi
        echo "Starting consumer for target '$consumerName'..."
        if ! "$SRC_PATH/.consume/$consumerName.sh" "$ORCH_SESSION_PATH/$consumerName" "$TGT_PATH/$consumerName"; then
            echo "Consumer for target '$consumerName' failed with exit code: $?"
            finalExitCode="2"
        fi
    done
else
    echo "This module does not consume any configuration."
fi

# ### Exit

exit "$finalExitCode"