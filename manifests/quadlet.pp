# @summary Manages the OpenTelemetry Collector as a podman quadlet container.
#
# Wraps quadlet::quadlet to declare an OTel Collector container unit,
# subscribing it to the collector configuration concat resource so that
# configuration changes trigger a container restart.
#
# The quadlet always subscribes to Concat['otel-config.yaml'].
# Callers may specify additional subscriptions (for example CA files) via the
# 'subscribe' key in $quadlet_params; these are merged with the
# mandatory subscription rather than replacing it.
#
# Most container-level settings (image, volumes, ports, environment, etc.)
# are passed through via $quadlet_params, which is forwarded directly to
# quadlet::quadlet.
# This avoids duplicating the upstream parameter list and remains
# forward-compatible with new quadlet::quadlet features.
# It does not permit settings which quadlet::quadlet forbids.
#
# Supporting quadlets (networks, volumes, etc.) may be declared via
# $extra_otel_collector_quadlets. Each extra quadlet will notify the main
# collector quadlet when it changes, which causes the collector to restart.
# Any caller-supplied notify values on extra quadlets are preserved and merged
# with the mandatory notify target.
#
# This design is intentionally one-directional (extras notify the main unit)
# to avoid notification cascades. Puppet will still restart the service more
# than once if multiple dependencies change in a run; this is expected.
#
# @param unit_name
#   Name of the main quadlet unit (without the .container suffix).
#   Determines the file written to /etc/containers/systemd/<unit_name>.container.
#
# @param quadlet_params
#   Hash of parameters passed through to quadlet::quadlet via the splat
#   operator. Any parameter accepted by quadlet::quadlet may be specified here.
#
#   Special handling:
#   - 'subscribe' is merged with Concat['otel-config.yaml'] (mandatory).
#
# @param extra_otel_collector_quadlets
#   Hash of additional quadlet::quadlet resources to declare.
#
#   Format:
#     { '<title>' => { <quadlet::quadlet params> }, ... }
#
#   Special handling (per extra quadlet):
#   - 'notify' is merged with Quadlet::Quadlet[$unit_name] (mandatory).
#
# @example Minimal usage
#   class { 'otel_collector::quadlet':
#     quadlet_params => {
#       'container_image' => 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.115.0',
#       'volumes'         => ['/etc/otel/otel-config.yaml:/etc/otelcol/config.yaml:ro,Z'],
#       'ports'           => ['4317:4317', '4318:4318'],
#     },
#   }
#
# @example Custom unit name
#   class { 'otel_collector::quadlet':
#     unit_name => 'my-otel',
#     quadlet_params => {
#       'container_image' => 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.115.0',
#       'volumes'         => ['/etc/otel/otel-config.yaml:/etc/otelcol/config.yaml:ro,Z'],
#     },
#   }
#
# @example Merge extra subscriptions (for example CA files)
#   class { 'otel_collector::quadlet':
#     quadlet_params => {
#       'container_image' => 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.115.0',
#       'volumes'         => [
#         '/etc/otel/otel-config.yaml:/etc/otelcol/config.yaml:ro,Z',
#         '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem:/etc/ssl/certs/ca-bundle.crt:ro,Z',
#       ],
#       'subscribe'       => File['/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem'],
#     },
#   }
#
# @example Extra quadlets that trigger collector restart when they change
#   class { 'otel_collector::quadlet':
#     quadlet_params => {
#       'container_image' => 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.115.0',
#       'volumes'         => ['/etc/otel/otel-config.yaml:/etc/otelcol/config.yaml:ro,Z'],
#     },
#     extra_otel_collector_quadlets => {
#       'otel-network' => {
#         # Example keys; use whatever quadlet::quadlet supports in your version.
#         'type'    => 'network',
#         'entries' => { 'Network' => { 'Subnet' => '10.89.0.0/24' } },
#       },
#       'otel-volume' => {
#         'type'   => 'volume',
#         # Preserves caller notify targets; merges with the main collector notify.
#         'notify' => Service['some-other.service'],
#       },
#     },
#   }
#
class otel_collector::quadlet (
  String[1]                      $unit_name                     = 'otel-collector.container',
  Hash[String, Any]              $quadlet_params                = {},
  Hash[String, Hash[String,Any]] $extra_otel_collector_quadlets = {},
) {
  include otel_collector::config

  # Mandatory subscription to collector config. Merge any caller-supplied
  # subscriptions from $quadlet_params['subscribe'].
  $_caller_subscribe = pick($quadlet_params['subscribe'], [])
  $_clean_params     = $quadlet_params - 'subscribe'
  $_subscribe        = flatten([Concat['otel-config.yaml'], $_caller_subscribe])

  quadlets::quadlet { $unit_name:
    *         => $_clean_params,
    subscribe => $_subscribe,
  }

  # Declare supporting quadlets (networks, volumes, ...). Each must notify the
  # main quadlet so the collector restarts when dependencies change. Merge any
  # caller-supplied notify targets rather than replacing them.
  $extra_otel_collector_quadlets.each |String $title, Hash $params| {
    $_caller_notify = pick($params['notify'], [])
    $_extra_clean   = $params - 'notify'
    $_notify        = flatten([Quadlets::Quadlet[$unit_name], $_caller_notify])

    quadlets::quadlet { $title:
      *      => $_extra_clean,
      notify => $_notify,
    }
  }

  systemd::daemon_reload { "otel_collector::quadlet::${unit_name}":
    subscribe => Quadlets::Quadlet[$unit_name],
  }
}
