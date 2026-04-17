# otel_collector

Deploys the [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/).
Configuration is assembled from ordered YAML fragments so multiple Hiera layers
or other modules can contribute pipeline components without replacing each
other.

The module is organized as two independent concerns:

- **Configuration** (`otel_collector::config`) - manages the collector's
  `otel-config.yaml` and the directory that contains it. Concerned only with
  file content, ownership, and the fragment assembly process.
- **Deployment** (`otel_collector::quadlet`) - runs the collector as a rootful
  podman quadlet container and wires its lifecycle to the configuration file.

The two can be used together (the common case) or the configuration class can
be used on its own.

## Table of Contents

1. [Description](#description)
1. [Requirements](#requirements)
1. [Setup](#setup)
1. [Configuration (`otel_collector::config`)](#configuration-otel_collectorconfig)
   - [Configuration assembly](#configuration-assembly)
   - [Adding configuration fragments from Hiera](#adding-configuration-fragments-from-hiera)
1. [Deployment (`otel_collector::quadlet`)](#deployment-otel_collectorquadlet)
   - [Minimal deployment](#minimal-deployment)
   - [Subscribing to additional files](#subscribing-to-additional-files)
   - [Running supporting quadlets](#running-supporting-quadlets)
1. [Reference](#reference)
1. [Limitations](#limitations)

## Description

This module provides:

- `otel_collector::config` - creates the configuration directory and assembles
  `otel-config.yaml` from ordered fragments using `puppetlabs/concat`.
- `otel_collector::config::add` - defined type for contributing additional YAML
  fragments into the assembled config from any Hiera layer or class.
- `otel_collector::quadlet` - declares the collector as a podman quadlet
  container unit, includes `otel_collector::config`, and subscribes the unit
  to the assembled config so the container restarts on config changes. Also
  optionally manages supporting quadlets (networks, volumes, sidecar
  containers).

## Requirements

- Puppet >= 8.0
- puppetlabs/stdlib >= 9.0
- puppetlabs/concat >= 9.0
- puppet/extlib >= 8.0
- puppet/systemd >= 8.0

Additional requirements when using `otel_collector::quadlet`:

- podman with quadlet support (podman >= 5.0)
- puppet/quadlets >= 3.0

## Setup

Include `otel_collector::quadlet` in your site manifest. All configuration is
driven through Hiera.

```puppet
# site.pp or a role class
include otel_collector::quadlet
```

`otel_collector::quadlet` automatically includes `otel_collector::config`, so
you do not need to declare both when deploying the collector as a container.

If you need only the assembled config file (for example, to consume it from a
separately managed collector process), include `otel_collector::config`
directly:

```puppet
include otel_collector::config
```

## Configuration (`otel_collector::config`)

`otel_collector::config` manages the config directory, assembles
`otel-config.yaml` from ordered fragments, and applies ownership, mode, and
SELinux labelling. It has no knowledge of how the collector is run.

### Configuration assembly

The collector config file (`/etc/otel-collector/otel-config.yaml` by default)
is assembled from one or more `concat::fragment` resources:

- **Order 0** - the base fragment, rendered from `otel_collector::config::config_defaults`.
- **Order 1-49** - reserved for fragments that should override defaults.
- **Order 50** - the default order for `otel_collector::config::add` resources.
  Suitable for additive configuration that does not conflict with the base.
- **Order 51+** - higher-order fragments contributed after the default add order.

Array values are uniq-concatenated across all fragments regardless of order.

Two fragments that define the same scalar key with different values will cause
a catalog compile error. Each fragment should own a distinct set of keys, or
use distinct named receivers/exporters to avoid conflicts.

The base configuration is set via `otel_collector::config::config_defaults`.
See `examples/basic.yaml` for a working minimal configuration that scrapes the
collector's own internal metrics and exposes them via a Prometheus exporter.

### Adding configuration fragments from Hiera

Use `otel_collector::config::config_adds` to contribute additional pipeline
components without replacing `config_defaults`. Set a `deep` merge strategy in
your `hiera.yaml` so fragments from multiple layers are combined:

```yaml
# hiera.yaml
lookup_options:
  otel_collector::config::config_adds:
    merge: deep
    merge_hash_arrays: true
    knockout_prefix: --
```

Example: add an OTLP receiver in a role layer and a forwarding exporter in an
environment layer, without either replacing the other:

```yaml
# roles/collector.yaml
otel_collector::config::config_adds:
  receivers/otlp:
    order: 10
    settings:
      receivers:
        otlp:
          protocols:
            grpc: {}
            http: {}
      service:
        pipelines:
          metrics:
            receivers: [otlp]
```

```yaml
# environments/production/data/common.yaml
otel_collector::config::config_adds:
  exporters/otlp-upstream:
    order: 50
    settings:
      exporters:
        otlp/upstream:
          endpoint: "otelcol.example.com:4317"
      service:
        pipelines:
          metrics:
            exporters: [otlp/upstream]
```

With a deep merge, both fragments are declared and the pipeline arrays are
uniq-concatenated into the final config.

This same pattern is used to add a scrape receiver for a companion service
such as `node_exporter`: declare a fragment that adds the receiver to
`receivers` and appends its name to the appropriate pipeline `receivers`
array.

## Deployment (`otel_collector::quadlet`)

`otel_collector::quadlet` runs the collector as a podman quadlet container
unit. It includes `otel_collector::config` and subscribes the unit to
`Concat[otel-config.yaml]` so the container restarts whenever the config file
changes.

### Minimal deployment

With only `include otel_collector::quadlet` and no Hiera data, the module
creates the config directory, assembles an empty `otel-config.yaml`, and
declares the quadlet unit with no container settings.
This will probably error out due to missing required values.

See `examples/basic.yaml` for a working minimal configuration.

### Subscribing to additional files

If the collector configuration references a CA bundle or a credentials file
that Puppet also manages, you can extend the quadlet's subscription so it
restarts when those files change:

```yaml
otel_collector::quadlet::quadlet_params:
  subscribe: "File[/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem]"
  container_entry:
    Volume:
      - "%{lookup('otel_collector::config::config_file')}:%{lookup('otel_collector::config::config_file')}:ro,z"
      - "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem:/etc/ssl/certs/ca-bundle.crt:ro,z"
```

The module merges the caller-supplied `subscribe` value with the mandatory
`Concat[otel-config.yaml]` subscription rather than replacing it.

### Running supporting quadlets

Additional quadlets (networks, volumes, sidecar containers, etc) can be
declared through `otel_collector::quadlet::extra_otel_collector_quadlets`.
Each extra quadlet automatically notifies the main collector unit when it
changes, so the collector restarts after any dependency changes.

Pair this with a `config_adds` fragment (see above) to both run the companion
service and extend the collector pipeline to scrape it.

## Reference

Full parameter documentation is generated by Puppet Strings and available in
[REFERENCE.md](REFERENCE.md).

Key classes and defined types:

| Name | Concern | Purpose |
|---|---|---|
| `otel_collector::config` | Configuration | Manages the config directory and assembles `otel-config.yaml` from fragments. |
| `otel_collector::config::add` | Configuration | Defined type for contributing a YAML fragment to the assembled config. |
| `otel_collector::quadlet` | Deployment | Runs the collector as a podman quadlet. Includes `otel_collector::config`. |

Configuration parameters (`otel_collector::config`):

| Parameter | Default | Purpose |
|---|---|---|
| `otel_collector::config::config_directory` | `/etc/otel-collector` | Config directory path. |
| `otel_collector::config::config_file` | `/etc/otel-collector/otel-config.yaml` | Assembled config file path. |
| `otel_collector::config::config_defaults` | `{}` | Base OTel config hash, rendered as concat fragment at order 0. |
| `otel_collector::config::config_adds` | `{}` | Named `otel_collector::config::add` resources declared via Hiera. Requires `deep` merge. |

Deployment parameters (`otel_collector::quadlet`):

| Parameter | Default | Purpose |
|---|---|---|
| `otel_collector::quadlet::unit_name` | `otel-collector.container` | Quadlet unit filename. |
| `otel_collector::quadlet::quadlet_params` | `{}` | Pass-through hash to `quadlets::quadlet`. Accepts `container_entry`, `service_entry`, `install_entry`, etc. |
| `otel_collector::quadlet::extra_otel_collector_quadlets` | `{}` | Supporting quadlets that notify the main collector unit when they change. |

## Limitations

- Tested on RHEL and AlmaLinux. The module is structurally distribution-neutral
  but SELinux defaults (`etc_t`) and the quadlet file path
  (`/etc/containers/systemd/`) are Linux/systemd-specific.
- `otel_collector::quadlet` requires podman >= 5.0 for good quadlet support.
  The `puppet/quadlets` module runs `podman system-generator --dryrun` to
  validate generated unit files.
- Configuration fragment scalar conflicts (two fragments defining the same key
  with different values) cause a hard catalog compile error. Design fragments
  to own distinct keys or use named receivers/exporters (e.g.,
  `prometheus/self`, `prometheus/node-exporter`) to avoid collisions.
