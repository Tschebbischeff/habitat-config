#!/usr/bin/env bash

set -euo pipefail

SOURCE_PATH="$1"
MODULE_CONSUMER_SCRIPT="$2"
[ -z "$SOURCE_PATH" ] && { echo "No configuration source directory provided."; exit 1; }
[ -d "$SOURCE_PATH" ] || { echo "Could not find configuration source directory '$SOURCE_PATH'."; exit 1; }
[ -z "$MODULE_CONSUMER_SCRIPT" ] && { echo "No consumer script provided."; exit 1; }
[ -f "$MODULE_CONSUMER_SCRIPT" ] || { echo "Could not find consumer script '$MODULE_CONSUMER_SCRIPT'."; exit 1; }
[ -x "$MODULE_CONSUMER_SCRIPT" ] || { echo "Consumer script '$MODULE_CONSUMER_SCRIPT' is not executable."; exit 1; }

IFS="," read -r -a tmp_modules <<< "${APP_MODULES}"
MODULES=()
for moduleName in "${tmp_modules[@]}"; do
    MODULES[${#MODULES[@]}]="$(echo "$moduleName" | xargs)"
done

MERGE_PATH="$SOURCE_PATH/.merged"
mkdir -p "$MERGE_PATH"

overrideFile() {
    # Override file "$2" with file "$1"
    local sourceFile="$1"
    local targetFile="$2"
    echo "Overriding '${sourceFile#"$SOURCE_PATH/"}' over '${targetFile#"$SOURCE_PATH/"}'"
    mkdir -p "$(dirname -- "$targetFile")"
    cp -f "$sourceFile" "$targetFile"
}

executeTransformer() {
    # Execute script file "$1" (transformer script) with argument "$2" (target file to transform), then write result to
    local transformerScript="$1"
    local targetFile="$2"
    echo "Using '${transformerScript#"$SOURCE_PATH/"}' to transform '${targetFile#"$SOURCE_PATH/"}'"
    mkdir -p "$(dirname -- "$targetFile")"
    touch "$targetFile"
    local transformerExitCode="0"
    mergedFileContents="$("$transformerScript" "$targetFile")"
    transformerExitCode="$?"
    if [ "$transformerExitCode" -eq "0" ]; then
        echo "$mergedFileContents" >"$targetFile"
    else
        echo "Error: Transformation script returned exit code '$transformerExitCode', leaving untransformed config file untouched."
    fi
}

mergeJSON() {
    # Merge file "$2" into file "$3", overriding duplicate object attributes on the deepest level possible, concatenating arrays if "$1" is non-empty
    local concatArrays="$1"
    local sourceFile="$2"
    local targetFile="$3"
    local mergedFileContents="";
    echo "Merging '${sourceFile#"$SOURCE_PATH/"}' into '${targetFile#"$SOURCE_PATH/"}'"
    mkdir -p "$(dirname -- "$targetFile")"
    touch "$targetFile"
    if [ "$concatArrays" ]; then
        # shellcheck disable=SC2016 # $item variable is part of jq expression and not to be expanded
        mergedFileContents="$(jq -rs 'reduce .[] as $item ({};
        def deepmerge(a; b): a as $a | b as $b |
            if ($a | type == "object") and ($b | type == "object") then
                reduce (
                    {a_keys: $a | keys_unsorted, b_keys: $b | keys_unsorted} | [.a_keys, .b_keys] | flatten | unique
                )[] as $k ({}; .[$k] = deepmerge($a[$k]; $b[$k]))
            elif ($a | type == "array") and ($b | type == "array") then
                [$a, $b] | flatten
            elif ($b | type == "null") then
                $a
            else
                $b
            end
        ;
        deepmerge(.; $item)
        )' "$targetFile" "$sourceFile")"
    else
        # shellcheck disable=SC2016 # $item variable is part of jq expression and not to be expanded
        mergedFileContents="$(jq -rs 'reduce .[] as $item ({}; . * $item)' "$targetFile" "$sourceFile")"
    fi
    echo "$mergedFileContents" >"$targetFile"
}

mergeYAML() {
    # Merge file "$1" into file "$2", overriding duplicate object attributes on the deepest level possible, concatenating arrays if "$1" is non-empty
    local concatArrays="$1"
    local sourceFile="$2"
    local targetFile="$3"
    local mergedFileContents="";
    echo "Merging '${sourceFile#"$SOURCE_PATH/"}' into '${targetFile#"$SOURCE_PATH/"}'"
    mkdir -p "$(dirname -- "$targetFile")"
    touch "$targetFile"
    if [ "$concatArrays" ]; then
        # shellcheck disable=SC2016 # $item variable is part of yq expression and not to be expanded
        mergedFileContents="$(yq eval-all '. as $item ireduce ({}; . *+ $item )' "$targetFile" "$sourceFile")"
    else
        # shellcheck disable=SC2016 # $item variable is part of yq expression and not to be expanded
        mergedFileContents="$(yq eval-all '. as $item ireduce ({}; . * $item )' "$targetFile" "$sourceFile")"
    fi
    echo "$mergedFileContents" >"$targetFile"
}

for moduleName in "${MODULES[@]}"; do
    [ ! -d "$SOURCE_PATH/$moduleName" ] && continue
    echo "* Merging configuration provided by '$moduleName' module..."
    (
        cd "$SOURCE_PATH/$moduleName"
        find . -type f -printf '%P\n' | sort | while read -r cfgRelFilePath; do
            cfgFileName="$(basename -- "$cfgRelFilePath")"
            cfgFileExtension="${cfgFileName##*.}"
            sourceFile="$SOURCE_PATH/$moduleName/$cfgRelFilePath"
            targetFile="$MERGE_PATH/$cfgRelFilePath"
            case "$cfgFileExtension" in
                "yml" | "yaml")
                    mergeYAML "" "$sourceFile" "$targetFile"
                ;;
                "json")
                    mergeJSON "" "$sourceFile" "$targetFile"
                ;;
                "sh")
                    if [ "${cfgFileName##*...}" != "sh" ]; then
                        overrideFile "$sourceFile" "$targetFile"
                    fi
                ;;
                *)
                    overrideFile "$sourceFile" "$targetFile"
                ;;
            esac
        done
    )
done

echo "* Evaluating priorities and overrides..."
(
    cd "$MERGE_PATH"
    find . -type f -printf '%P\n' | sort | while read -r cfgRelFilePath; do
        cfgFileName="$(basename -- "$cfgRelFilePath")"
        cfgFileExtension="${cfgFileName##*.}"
        cfgFileBaseName="${cfgFileName%.*}"
        cfgFileInstructions="${cfgFileBaseName##*.}"
        if echo "$cfgFileInstructions" | grep -Pqv '^hbt-([oa]-)?[0-9]+$' || [ "$cfgFileInstructions" == "$cfgFileBaseName" ]; then
            # No instructions found, this is a normal file that has already been merged => Skip
            continue
        fi
        cfgFileBaseName="${cfgFileBaseName%.*}"
        cfgFileInstructions="${cfgFileInstructions##hbt-}"
        cfgFileShouldOverride=""
        echo "$cfgFileInstructions" | grep -Pq '^o-' && cfgFileShouldOverride="_"
        cfgFileConcatArrays=""
        echo "$cfgFileInstructions" | grep -Pq '^a-' && cfgFileConcatArrays="_"
        sourceFile="$MERGE_PATH/$cfgRelFilePath"
        targetFile="$MERGE_PATH/$(dirname -- "$cfgRelFilePath")/$cfgFileBaseName.$cfgFileExtension"
        { [ "$cfgFileShouldOverride" ] && overrideFile "$sourceFile" "$targetFile"; } || \
        case "$cfgFileExtension" in
            "yml" | "yaml")
                mergeYAML "$cfgFileConcatArrays" "$sourceFile" "$targetFile"
            ;;
            "json")
                mergeJSON "$cfgFileConcatArrays" "$sourceFile" "$targetFile"
            ;;
            *)
                echo "Warning: Merge not supported for extension '$cfgFileExtension', overriding instead"
                overrideFile "$sourceFile" "$targetFile"
            ;;
        esac
        rm "$sourceFile"
    done
)

for moduleName in "${MODULES[@]}"; do
    [ ! -d "$SOURCE_PATH/$moduleName" ] && continue
    echo "* Executing consumer-side transformation scripts from '$moduleName' module..."
    (
        cd "$SOURCE_PATH/$moduleName"
        find . -name '*...sh' -type f -printf '%P\n' | sort | while read -r cfgRelFilePath; do
            [ -x "$cfgRelFilePath" ] || continue
            cfgFileName="$(basename -- "$cfgRelFilePath")"
            cfgFileBaseName="${cfgFileName%...*}"
            executeTransformer "$SOURCE_PATH/$moduleName/$cfgRelFilePath" "$MERGE_PATH/$(dirname -- "$cfgRelFilePath")/$cfgFileBaseName"
        done
    )
done

echo "Delegating to module consumer script '$MODULE_CONSUMER_SCRIPT'..."

"$MODULE_CONSUMER_SCRIPT" "$MERGE_PATH"
exit "$?"
