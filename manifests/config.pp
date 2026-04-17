# @summary Manages the OpenTelemetry Collector configuration directory and base config file.
#
# Creates the configuration directory and assembles the primary YAML configuration
# file from ordered fragments using `concat`. The base fragment (order 0) is
# rendered from a hash of default settings; additional fragments are contributed
# by other classes or defined types (e.g., pipeline components) via
# `concat::fragment`.
#
# SELinux context defaults to `etc_t`, appropriate for files under `/etc` on
# RHEL/AlmaLinux. Adjust `config_seltype` if the collector runs under a confined
# domain that requires a more specific type.
#
# @example Minimal inclusion with defaults
#   include otel_collector::config
#
# @example Override config path and inject default settings
#   class { 'otel_collector::config':
#     config_file    => '/etc/otel-collector/otel-config.yaml',
#     config_defaults => {
#       'extensions' => { 'health_check' => {} },
#       'service'    => { 'extensions' => ['health_check'] },
#     },
#   }
#
# @param config_directory
#   Absolute path to the directory that holds collector configuration files.
#   Created as a directory with the ownership and mode specified by the
#   `config_owner`, `config_group`, and `config_mode` parameters.
#
# @param config_file
#   Absolute path to the assembled YAML configuration file managed by `concat`.
#   Must reside within `config_directory` for predictable SELinux labelling.
#
# @param config_owner
#   Unix user that owns the configuration directory and file.
#   Defaults to `root`. Change only if the collector daemon runs as a
#   dedicated service account that requires direct read access without
#   privilege escalation.
#
# @param config_group
#   Unix group assigned to the configuration directory and file.
#   Defaults to `root`. Adjust to a shared group when multiple processes or
#   administrators need read access without granting world-readable permissions.
#
# @param config_mode
#   Octal permission mode applied to both the directory and the config file.
#   Defaults to `0400` (owner read-only) to prevent unintentional modification
#   or exposure of pipeline credentials embedded in the config.
#   Use `0440` if a non-root service account in `config_group` must read the file.
#   Puppet will automatically add execute to directories as needed.
#
# @param config_seltype
#   SELinux type label applied to the configuration directory and file.
#   Defaults to `etc_t`, which is correct for static config files under `/etc`
#   on a standard RHEL/AlmaLinux policy. Override with a collector-specific
#   type (e.g., `otelcol_etc_t`) if a custom policy is deployed.
#
# @param config_defaults
#   Hash of top-level YAML keys merged into the base configuration fragment
#   (concat order 0) via the `otel_collector/etc/otel-collector/settings.epp`
#   template. Accepts any structure valid in an OTel Collector config file
#   (receivers, processors, exporters, extensions, service, etc.).
#   Downstream fragments at higher order values will be merged on top of
#   these defaults.
#@param config_adds
#   Hash of named `otel_collector::config::add` instances to declare via Hiera.
#   Each key becomes the resource title; the value is a hash of parameters
#   passed via splat. Only `settings` is required; `order` falls through to
#   `otel_collector::config::add`'s default of 50 when omitted.
#   Hiera should use a `deep` merge strategy so fragment definitions composed
#   across multiple layers are combined rather than replaced.
#
#   Example (Hiera):
#     otel_collector::config::config_adds:
#       receivers/otlp:
#         settings:
#           receivers:
#             otlp:
#               protocols:
#                 grpc: {}
#       exporters/otlp:
#         order: 70
#         settings:
#           exporters:
#             otlp/upstream:
#               endpoint: 'otelcol:4317'
class otel_collector::config (
  Stdlib::Absolutepath $config_directory = '/etc/otel-collector',
  Stdlib::Absolutepath $config_file = '/etc/otel-collector/otel-config.yaml',
  Variant[String[1], Integer] $config_owner = 'root',
  Variant[String[1], Integer] $config_group = 'root',
  String $config_mode = '0400',
  String $config_seltype = 'etc_t',
  Hash $config_defaults = {},
  Hash $config_adds = {},
) {
  file { $config_directory:
    ensure  => directory,
    owner   => $config_owner,
    group   => $config_group,
    mode    => $config_mode,
    seltype => $config_seltype,
  }

  concat { 'otel-config.yaml':
    ensure  => present,
    path    => $config_file,
    owner   => $config_owner,
    group   => $config_group,
    mode    => $config_mode,
    seltype => $config_seltype,
    format  => 'yaml',
  }

  concat::fragment { '000-otel-config-defaults':
    target  => 'otel-config.yaml',
    order   => 0,
    content => epp('otel_collector/etc/otel-collector/settings.epp', { 'settings' => $config_defaults }),
  }

  $config_adds.each |String[1] $title, Hash $entry| {
    otel_collector::config::add { $title:
      * => $entry,
    }
  }
}
