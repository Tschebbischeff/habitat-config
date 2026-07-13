[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat)](./LICENSE)
![Development: Prototyping](https://img.shields.io/badge/Development-Prototyping-orange?style=flat)
![Version](https://img.shields.io/badge/dynamic/json?label=Version&color=yellow&style=flat&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftschebbischeff%2Fhabitat-config%2Frefs%2Fheads%2Fmain%2Fmetadata.json&query=%24.version)

# Habitat: Config

> [!CAUTION]
> **🚧 This project is currently under heavy development, any information may be subject to change. 🚧**

Habitat provides modular functionality for deployment on home lab devices. \
Each of the modules is designed as an opinionated docker stack that can be deployed on its own or together with other modules by sharing the same docker network.

You can check out all officially available modules [here](https://github.com/Tschebbischeff/habitat#officially-available-modules).

## Our Principles

![TODO](https://img.shields.io/badge/TODO-Coming_Soon_(TM)-red?style=flat)

## Features

 - **Cross-Module Configuration via Sidecar** \
 Inject configuration into other habitat modules by defining a sidecar container, merging the configuration with other modules that are doing the same.
 - **Merge and Override Configuration** \
 Based on priority numbers select which module's configuration takes precedence in merging or whether to completely override a configuration file.

### Planned
 - **Generalized Merge and Override Logic** \
 Modules implementing consumers should simply get the result of the merge and override for the most common config file types (YAML, JSON, INI, etc.)

## Getting Started

This is not a Habitat module on its own, its designed as an interface so modules can supply or add to configuration for other modules (e.g. traefik configuration files, provisioning files, etc.)

### Defining Configuration

 - Create a habitat-config folder inside your module and place folders and files required for the cross-module configuration inside
 - Check which folders and files to create for the module in the documentation of that module

#### File Prioritization

You can merge or override configuration files supplied by other modules via the filename. \
A configuration file's base name (before extension) can be suffixed with instructions for prioritization and overriding, e.g.:
 - `base.hbt-000.yml` to merge this file into `base.yml` with arrays being overwritten
 - `base.hbt-a-000.yml` to merge this file into `base.yml` with arrays being concatenated
 - `base.hbt-o-000.yml` to fully override `base.yml` with this file

The prioritization number at the end applies as follows: \
`base.yml` < `base.hbt-000.yml` < `base.hbt-001.yml` < `base.hbt-a-001.yml` | `base.hbt-o-001.yml` < `base.hbt-002.yml`

(`A < B` means B is merged into A; `... | C` means all previous files are replaced by C) \

All files with the exact same name (even if they define a priority) are merged in the order in which modules are listed in the APP_MODULES environment variable. Later list entries are merged into/ override earlier ones. \
This step happens before the actual prioritization instructions are processed.

Extensive Example:
 - Let `APP_MODULES="module-a,module-b,module-d,module-c,module-e,module-f,module-g"`
 - Module A provides `{habitat-config}/foo/bar.json`
 - Module B provides `{habitat-config}/foo/bar.hbt-000.json`
   - B is merged into A, overriding duplicate attributes, forming the result `Merge(B, A)`
 - Module C provides `{habitat-config}/foo/bar.hbt-050.json`
   - C is merged into `Merge(B, A)`, forming the result `Merge(C, Merge(B, A))`
 - Module D provides `{habitat-config}/foo/bar.hbt-050.json`
   - Merge order between C and D is determined by order in `APP_MODULES`, since the files share the exact same name, same file name prioritization is resolved before instruction based prioritization
   - The result is `Merge(Merge(C, D), Merge(B, A))` since modules later in the list override earlier ones
 - Module E provides `{habitat-config}/foo/bar.hbt-o-050.json`
   - Overrides are applied after merging of the same priority, the result would now simply be the config file of Module E
 - Module F provides `{habitat-config}/foo/bar.hbt-100.json`
   - F is merged into E, which previously overrode the current config, forming the result `Merge(F, E)`
 - Module G provides `{habitat-config}/foo/bar.hbt-o-999.json`
   - This config file takes the highest precedence possible and will be the final result for the config file `bar.json`

### Manually transforming Files

You can define a executable file that is supposed to transform the configuration file `{habitat-config}/foo/bar.yml` by including a file at the same path inside your module and giving it the additional extension `...sh`, e.g. `{habitat-config}/foo/bar.yml...sh`.

The script is called after all initial merges, overrides and prioritizations have been applied and receives the path to the target configuration file as its only argument.

The output of the script is used as the new configuration file at that target path if the script returns with exit code zero.

Example, replace all occurrences of `foo` with `bar` in the target configuration file:
```sh
#!/usr/bin/env bash

set -euo pipefail

TARGET_FILE="$1"
TARGET_FILE_CONTENT="$(cat "$TARGET_FILE")"

echo "$TARGET_FILE_CONTENT" | sed 's/foo/bar/g'

exit 0
```

### Run the Sidecar

 - In your module's compose.yml define a habitat-config sidecar container according to the [example compose.yml](./examples/compose.provider.yml).

### Consume Configuration

To consume configuration means to move the result of merging and overrides to places where your module's services accept them, if the same config is used for multiple services you can also transform the configuration for each one of them.

To consume configuration you must define a consumer script inside the `habitat-config/.consume` folder of your module.

It must be an executable shell script and the name of the script is the "name of the consumer".

E.g. `habitat-config/.consume/my_service_consumer.sh` defines that your sidecar will manage configuration files that other modules (or your own) place inside `habitat-config/my_service_consumer`.

The script is called as a final step after the configuration provided by all modules has been merged, prioritized and/ or overriden according to the above rules.

The script receives one argument, the "source path", at which the configuration files can be found. \
If no modules provided any configuration, the directory may be empty, but it should always exist.

The simplest form of a consumer script just removes old configuration and copies over the new configuration to a volume shared with a service that will use the files.

Example:

```sh
#!/usr/bin/env bash

set -euo pipefail

SOURCE_PATH="$1"; [ -d "$SOURCE_PATH" ] || { echo "'$SOURCE_PATH' not found."; exit 1; }
TARGET_PATH="/habitat-config/target/MY_MOUNTED_VOLUME"; [ -d "$TARGET_PATH" ] || { echo "'$TARGET_PATH' not mounted."; exit 1; }

echo "Cleaning previous configuration at '$TARGET_PATH'"
rm -rf "${TARGET_PATH:?}/"{*,.*} &>/dev/null

echo "Copying new configuration to '$TARGET_PATH'"
cp -rp "$SOURCE_PATH/." "$TARGET_PATH/"

exit 0
```

This would require a named docker volume, mounted at the path `/habitat-config/target/MY_MOUNTED_VOLUME` which can also be mounted to other services that require the config.

If the service requiring the configuration should wait for the configuration to be finalized, add a depends_on condition to your compose.yml file:

```yaml
depends_on:
  habitat-config-YOURMODULENAME:
    condition: service_completed_successfully
```

The following dependencies are available for your consumer script to use:
 - jq
 - yq
 - grep
 - find (GNU version)


## Build

 - Run `docker run --privileged --rm tonistiigi/binfmt --install all` to enable cross-compilation for all alpine-supported architectures
 - Run `build.sh REPOSITORY` with a proper repository argument referring to your username/ company name on Docker Hub
 - Use `image: REPOSITORY/habitat-config:latest` instead of `image: tschebbischeff/habitat-config:latest` in your module's compose.yml

## Acknowledgments and Licensing

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE).

Copyright (c) 2026, [Tschebbischeff](https://github.com/Tschebbischeff). \
All rights reserved to the extent permitted by the AGPLv3.

For third-party license details and attribution, please see [Third-Party Licenses](./THIRD-PARTY-LICENSES.md).