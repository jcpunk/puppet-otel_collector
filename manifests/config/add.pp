# @summary Adds a configuration fragment to the OpenTelemetry Collector YAML config.
#
# Contributes one or more OpenTelemetry Collector configuration sections
# (e.g., receivers, exporters, processors, service) as an ordered fragment into the
# assembled otel-config.yaml via concat. Each instantiation merges a YAML block
# serialized from the provided settings hash.
#
# Fragment ordering is global across all contributors to otel-config.yaml. Callers
# should coordinate order values to control merge behavior. The default of
# 50 places fragments in the middle of the process; use lower values for
# sections that you might want to override, and higher values for sections that
# are the overrides.
#
# The fragment title is derived from the Puppet resource title (namevar), namespaced
# with the module name and order to prevent collisions with other modules targeting
# the same concat target.
#
# @param order
#   Numeric ordering key passed to concat::fragment. Controls the position of this
#   fragment within the assembled otel-config.yaml. Must be greater than 0.
#   Default: 50
#
# @param settings
#   Hash of one or more top-level OpenTelemetry Collector config sections to
#   serialize as YAML. Keys should be valid OTel config section names.
#   Example:
#     { 'receivers' => { 'otlp' => { 'protocols' => { 'grpc' => {} } } } }
#   Default: {}
#
# @example Add a receivers section at default order
#   otel_collector::config::add { 'receivers/otlp':
#     settings => {
#       'receivers' => {
#         'otlp' => {
#           'protocols' => { 'grpc' => {}, 'http' => {} },
#         },
#       },
#     },
#   }
#
# @example Add the service pipeline block
#   otel_collector::config::add { 'service':
#     order    => 90,
#     settings => {
#       'service' => {
#         'pipelines' => {
#           'traces' => {
#             'receivers'  => ['otlp'],
#             'exporters'  => ['otlp/upstream'],
#           },
#         },
#       },
#     },
#   }
#
define otel_collector::config::add (
  Integer[1] $order    = 50,
  Hash       $settings = {},
) {
  concat::fragment { "otel_collector-${order}-${title}":
    target  => 'otel-config.yaml',
    order   => $order,
    content => epp('otel_collector/etc/otel-collector/settings.epp', { 'settings' => $settings }),
  }
}
