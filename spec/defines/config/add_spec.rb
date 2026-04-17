# frozen_string_literal: true

require 'spec_helper'

describe 'otel_collector::config::add' do
  let(:title) { 'namevar' }
  let(:params) do
    {}
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'without parameters' do
        it { is_expected.to compile }
        it {
          is_expected.to contain_concat__fragment('otel_collector-50-namevar')
            .with_target('otel-config.yaml')
            .with_order(50)
            .with_content("--- {}\n")
        }
      end

      context 'with interesting parameters' do
        let(:params) do
          {
            'order' => 30,
      'settings' => { 'processors' => {} },
          }
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_concat__fragment('otel_collector-30-namevar')
            .with_target('otel-config.yaml')
            .with_order(30)
            .with_content("---\nprocessors: {}\n")
        }
      end
    end
  end
end
