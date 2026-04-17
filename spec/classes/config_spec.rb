# frozen_string_literal: true

require 'spec_helper'

describe 'otel_collector::config' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'without parameters' do
        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/etc/otel-collector')
            .with_ensure('directory')
            .with_owner('root')
            .with_group('root')
            .with_mode('0400')
            .with_seltype('etc_t')
        }
        it {
          is_expected.to contain_concat('otel-config.yaml')
            .with_ensure('present')
            .with_path('/etc/otel-collector/otel-config.yaml')
            .with_owner('root')
            .with_group('root')
            .with_mode('0400')
            .with_seltype('etc_t')
            .with_format('yaml')
        }
        it {
          is_expected.to contain_concat__fragment('000-otel-config-defaults')
            .with_target('otel-config.yaml')
            .with_order(0)
            .with_content("--- {}\n")
        }
      end
      context 'with interesting parameters' do
        let(:params) do
          {
            'config_directory' => '/tmp/foo',
            'config_file' => '/tmp/foo/conf',
            'config_owner' => 'nobody',
            'config_group' => 30,
            'config_mode' => '1777',
            'config_seltype' => 'home_t',
            'config_defaults' => {
              'extensions' => { 'ext' => ['c', 'a', 'b'] },
              'processors' => { 'proc' => 'asdf' },
              'exporters'  => { 'export' => { 'xx' => 'yy', 'jkl' => 'qwe', 'yui' => 'njo' }, 'export_list' => ['c', 'd'] },
              'service' => { 'serv' => ['kl', { 'rn' => 'ee' }] },
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/tmp/foo')
            .with_ensure('directory')
            .with_owner('nobody')
            .with_group(30)
            .with_mode('1777')
            .with_seltype('home_t')
        }
        it {
          is_expected.to contain_concat('otel-config.yaml')
            .with_ensure('present')
            .with_path('/tmp/foo/conf')
            .with_owner('nobody')
            .with_group(30)
            .with_mode('1777')
            .with_seltype('home_t')
            .with_format('yaml')
        }
        it {
          # rubocop:disable Layout/LineLength
          is_expected.to contain_concat__fragment('000-otel-config-defaults')
            .with_target('otel-config.yaml')
            .with_order(0)
            .with_content("---\nexporters:\n  export:\n    jkl: qwe\n    xx: yy\n    yui: njo\n  export_list:\n  - c\n  - d\nextensions:\n  ext:\n  - c\n  - a\n  - b\nprocessors:\n  proc: asdf\nservice:\n  serv:\n  - kl\n  - rn: ee\n")
          # rubocop:enable Layout/LineLength
        }
      end

      context 'with config_adds' do
        let(:params) do
          {
            'config_adds' => {
              'receivers/otlp' => {
                'order' => 30,
                'settings' => {
                  'receivers' => {
                    'otlp' => { 'protocols' => { 'grpc' => {} } },
                  },
                },
              },
              'exporters/otlp' => {
                'order' => 70,
                'settings' => {
                  'exporters' => {
                    'otlp/upstream' => { 'endpoint' => 'otelcol:4317' },
                  },
                },
              },
              'service' => {
                'settings' => {
                  'service' => {
                    'pipelines' => {
                      'traces' => {
                        'receivers' => ['otlp'],
                        'exporters' => ['otlp/upstream'],
                      },
                    },
                  },
                },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to have_concat__fragment_resource_count(4) }

        it {
          is_expected.to contain_concat__fragment('otel_collector-30-receivers/otlp')
            .with_target('otel-config.yaml')
            .with_order(30)
        }
        it {
          is_expected.to contain_otel_collector__config__add('receivers/otlp')
        }

        it {
          is_expected.to contain_concat__fragment('otel_collector-70-exporters/otlp')
            .with_target('otel-config.yaml')
            .with_order(70)
        }
        it {
          is_expected.to contain_otel_collector__config__add('exporters/otlp')
        }

        it {
          # order key omitted in config_adds entry; falls through to ::add default of 50
          is_expected.to contain_concat__fragment('otel_collector-50-service')
            .with_target('otel-config.yaml')
            .with_order(50)
        }
        it {
          is_expected.to contain_otel_collector__config__add('service')
        }

        it {
          is_expected.to contain_concat__fragment('otel_collector-30-receivers/otlp')
            .with_content("---\nreceivers:\n  otlp:\n    protocols:\n      grpc: {}\n")
        }

        it {
          is_expected.to contain_concat__fragment('otel_collector-70-exporters/otlp')
            .with_content("---\nexporters:\n  otlp/upstream:\n    endpoint: otelcol:4317\n")
        }

        it {
          is_expected.to contain_concat__fragment('otel_collector-50-service')
            .with_content("---\nservice:\n  pipelines:\n    traces:\n      exporters:\n      - otlp/upstream\n      receivers:\n      - otlp\n")
        }
      end
    end
  end
end
