[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat)](./LICENSE)
![Development: Prototyping](https://img.shields.io/badge/Development-Prototyping-orange?style=flat)
![Version](https://img.shields.io/badge/dynamic/json?label=Version&color=yellow&style=flat&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftschebbischeff%2Fhabitat-config%2Frefs%2Fheads%2Fmain%2Fmetadata.json&query=%24.version)

# Habitat: Config

**🚧
This project is currently under heavy development, any information may be subject to change.
🚧**

Habitat provides modular functionality for deployment on home lab devices. \
Each of the modules is designed as an opinionated docker stack that can be deployed on its own or together with other modules by sharing the same docker network.

## Available Modules

 - **[Path](https://github.com/Tschebbischeff/habitat-path)** \
 Connectivity and Routing
 - **[Scent](https://github.com/Tschebbischeff/habitat-scent)** \
 Authentication and User Management
 - **[Chatter](https://github.com/Tschebbischeff/habitat-chatter)** \
 Communication between modules
 - **[Hoard](https://github.com/Tschebbischeff/habitat-hoard)** \
 Data storage
 - **[Vigil](https://github.com/Tschebbischeff/habitat-vigil)** \
 Monitoring
 - **[Vista](https://github.com/Tschebbischeff/habitat-vista)** \
 Dashboards and User Interfaces

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

You can merge or override configuration files supplied by other modules via the filename. \
A configuration file's base name (before extension) can be suffixed with `.hbtprio-000` or `.hbtprio-override-000` to merge or override the base file at a specific point in the chain (`000` is the priority number).

I.e.: \
(`A < B` means B is merged into A; `... | C` means all previous files are replaced by C) \
`base.yml` < `base.hbtprio-000.yml` < `base.hbtprio-001.yml` | `base.hbtprio-override-001.yml` < `base.hbtprio-002.yml`

All files with the exact same name (even if they define a priority) are merged before priorities are applied. \
*The merge order for files with the exact same name is undefined!*

Example:
 - Module A provides `{habitat-config}/foo/bar.json`
 - Module B provides `{habitat-config}/foo/bar.hbtprio-000.json`
   - B is merged into A, overriding duplicate attributes, forming the result `Merge(B, A)`
 - Module C provides `{habitat-config}/foo/bar.hbtprio-050.json`
   - C is merged into `Merge(B, A)`, forming the result `Merge(C, Merge(B, A))`
 - Module D provides `{habitat-config}/foo/bar.hbtprio-050.json`
   - Merge order between C and D is undefined, since they share the exact same name, the result of that undefined merge is merged into `Merge(B, A)`
 - Module E provides `{habitat-config}/foo/bar.hbtprio-override-050.json`
   - Overrides are applied after merging of the same priority, the result will be the config file of Module E
 - Module F provides `{habitat-config}/foo/bar.hbtprio-100.json`
   - F is merged into E, which previously overrode the current config for `bar.json`, forming the result `Merge(F, E)`
 - Module G provides `{habitat-config}/foo/bar.hbtprio-override-999.json`
   - This config file takes absolute precedence and will be the final result for `bar.json`

### Run the Sidecar

 - In your module's compose.yml define a habitat-config sidecar container according to the [example compose.yml](./examples/compose.yml).

### Consume Configuration

To consume configuration means to apply merging and overrides according to the rules, then make the configuration available to one or multiple services inside your module in a form they expect.

To consume configuration you must define a consumer script inside the `habitat-config/.consume` folder of your module.

It must be a shell script and the name of the script is the "name of the consumer".

E.g. `habitat-config/.consume/my_service_consumer.sh` defines that your sidecar will manage configuration files that other modules (or your own) place inside `habitat-config/my_service_consumer`.

The script is called after all modules have started and made their configuration available via the shared `habitat-config` volume.

The script receives one argument, the "source path", containing one folder for each module that provided configuration for your consumer. \
The source path may therefore be an empty directory.

After applying merges and overrides your consumer can copy the final configuration to other mounted volumes which can be mounted in other services of your modules.
By convention you should mount these volumes at `/habitat-config/target/my_service_consumer` within your sidecar container.

You can check the habitat-path module's [traefik config consumer](https://github.com/Tschebbischeff/habitat-path/blob/main/habitat-config/.consume/traefik.sh) to see how a consumer script could be defined.


## Build

 - Run `docker run --privileged --rm tonistiigi/binfmt --install all` to enable cross-compilation for all alpine-supported architectures
 - Run `build.sh REPOSITORY` with a proper repository argument referring to your username/ company name on Docker Hub
 - Use `image: REPOSITORY/habitat-config:latest` instead of `image: tschebbischeff/habitat-config:latest` in your module's compose.yml

## Acknowledgments and Licensing

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE).

Copyright (c) 2026, [Tschebbischeff](https://github.com/Tschebbischeff). \
All rights reserved to the extent permitted by the AGPLv3.

For third-party license details and attribution, please see [Third-Party Licenses](./THIRD-PARTY-LICENSES.md).