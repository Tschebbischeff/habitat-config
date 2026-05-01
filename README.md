[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat)](./LICENSE)
![Development: Prototyping](https://img.shields.io/badge/Development-Prototyping-orange?style=flat)
![Version](https://img.shields.io/badge/dynamic/json?label=Version&color=yellow&style=flat&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftschebbischeff%2Fhabitat-path%2Frefs%2Fheads%2Fmain%2Fmetadata.json&query=%24.version)

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

### Planned
 - **Docker Compose Merge Configuration**
 Use by merging premade compose files for each configurable module instead of defining a sidecar per module

## Getting Started

This is not a Habitat module on its own, its designed as an interface so modules can supply or add to configuration for other modules (e.g. traefik configuration files, provisioning files, etc.)

### Configuration

 - Create a habitat-config folder inside your module and place folders and files required for the cross-module configuration inside
 - Check which folders and files to create for the module in the documentation of that module

### Run as a Sidecar

 - In your module's compose.yml define a habitat-config sidecar container by using one of the examples in the example folder (or merging multiple into one sidecar config)

## Build

![TODO](https://img.shields.io/badge/TODO-Coming_Soon_(TM)-red?style=flat)

## Acknowledgments and Licensing

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE).

Copyright (c) 2026, [Tschebbischeff](https://github.com/Tschebbischeff). \
All rights reserved to the extent permitted by the AGPLv3.

For third-party license details and attribution, please see [Third-Party Licenses](./THIRD-PARTY-LICENSES.md).