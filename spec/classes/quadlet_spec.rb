# frozen_string_literal: true

require 'spec_helper'

describe 'otel_collector::quadlet' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'without parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('otel-collector.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }

        it {
          is_expected.to have_quadlets__quadlet_resource_count(1)
        }

        it {
          is_expected.to contain_systemd__daemon_reload('otel_collector::quadlet::otel-collector.container')
            .that_subscribes_to('Quadlets::Quadlet[otel-collector.container]')
        }
      end

      context 'with a custom unit_name' do
        let(:params) do
          {
            'unit_name' => 'my-otel.container',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('my-otel.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }

        it {
          is_expected.not_to contain_quadlets__quadlet('otel-collector.container')
        }

        it {
          is_expected.to contain_systemd__daemon_reload('otel_collector::quadlet::my-otel.container')
            .that_subscribes_to('Quadlets::Quadlet[my-otel.container]')
        }
      end

      context 'with quadlet_params' do
        let(:params) do
          {
            'quadlet_params' => {
              'container_entry' => {},
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('otel-collector.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }
      end

      context 'with caller-supplied subscribe in quadlet_params' do
        let(:pre_condition) do
          <<~PP
            file { '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem':
              ensure => file,
            }
PP
        end

        let(:params) do
          {
            'quadlet_params' => {
              'subscribe' => 'File[/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem]',
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('otel-collector.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }

        it {
          is_expected.to contain_quadlets__quadlet('otel-collector.container')
            .that_subscribes_to('File[/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem]')
        }
      end

      context 'with extra_otel_collector_quadlets' do
        let(:params) do
          {
            'extra_otel_collector_quadlets' => {
              'otel-network.network' => {
                'network_entry' => {}
              },
              'otel-volume.volume' => {
                'volume_entry' => {}
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to have_quadlets__quadlet_resource_count(3)
        }

        it {
          is_expected.to contain_quadlets__quadlet('otel-network.network')
            .that_notifies('Quadlets::Quadlet[otel-collector.container]')
        }

        it {
          is_expected.to contain_quadlets__quadlet('otel-volume.volume')
            .that_notifies('Quadlets::Quadlet[otel-collector.container]')
        }

        it {
          is_expected.to contain_quadlets__quadlet('otel-collector.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }
      end

      context 'with caller-supplied notify in extra_otel_collector_quadlets' do
        let(:pre_condition) do
          <<~PP
            service { 'some-other.service': }
PP
        end

        let(:params) do
          {
            'extra_otel_collector_quadlets' => {
              'otel-volume.volume' => {
                'volume_entry' => {},
                'notify' => 'Service[some-other.service]',
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('otel-volume.volume')
            .that_notifies('Quadlets::Quadlet[otel-collector.container]')
        }

        it {
          is_expected.to contain_quadlets__quadlet('otel-volume.volume')
            .that_notifies('Service[some-other.service]')
        }
      end

      context 'with extra_otel_collector_quadlets and custom unit_name' do
        let(:params) do
          {
            'unit_name' => 'my-otel.container',
            'extra_otel_collector_quadlets' => {
              'my-otel-network.network' => {
                'network_entry' => {},
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_quadlets__quadlet('my-otel-network.network')
            .that_notifies('Quadlets::Quadlet[my-otel.container]')
        }

        it {
          is_expected.to contain_quadlets__quadlet('my-otel.container')
            .that_subscribes_to('Concat[otel-config.yaml]')
        }
      end

      context 'with empty extra_otel_collector_quadlets' do
        let(:params) do
          {
            'extra_otel_collector_quadlets' => {},
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to have_quadlets__quadlet_resource_count(1)
        }
      end
    end
  end
end
