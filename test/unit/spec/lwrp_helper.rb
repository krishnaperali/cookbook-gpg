require 'chefspec'
require 'rspec/collection_matchers'

module BswTech
  module ChefSpec
    module LwrpTestHelper
      def generated_cookbook_path
        File.join File.dirname(__FILE__), 'gen_cookbooks'
      end

      def cookbook_path
        File.join generated_cookbook_path, generated_cookbook_name
      end

      def generated_cookbook_name
        'lwrp_gen'
      end

      RSpec.configure do |config|
        config.before(:each) do
          stub_resources
          @gpg_interface = double
          @trustdb_suppress = nil
          allow(BswTech::Gpg::GpgInterface).to receive(:new) do |suppress_trust_db|
            @trustdb_suppress = suppress_trust_db
            @gpg_interface
          end
          @base64_used = nil
          @current_key_checks = []
          @keytrusts_imported = []
          @keys_imported = []
          @keys_deleted = []
        end

        config.after(:each) do
          cleanup
        end
      end

      def temp_lwrp_recipe(contents)
        runner_options = {}
        create_temp_cookbook(contents)
        RSpec.configure do |config|
          # noinspection RubyResolve
          config.cookbook_path = [*config.cookbook_path] << generated_cookbook_path
        end
        lwrps_full = [*lwrps_under_test].map do |lwrp|
          "#{cookbook_under_test}_#{lwrp}"
        end
        @chef_run = ::ChefSpec::SoloRunner.new(runner_options.merge(step_into: lwrps_full))
        @chef_run.converge("#{generated_cookbook_name}::default")
      end

      def create_temp_cookbook(contents)
        the_path = cookbook_path
        recipes = File.join the_path, 'recipes'
        FileUtils.mkdir_p recipes
        File.open File.join(recipes, 'default.rb'), 'w' do |f|
          f << contents
        end
        File.open File.join(the_path, 'metadata.rb'), 'w' do |f|
          f << "name '#{generated_cookbook_name}'\n"
          f << "version '0.0.1'\n"
          f << "depends '#{cookbook_under_test}'\n"
        end
      end

      def cleanup
        FileUtils.rm_rf generated_cookbook_path
      end

      def stub_gpg_interface(current=[], draft)
        allow(@gpg_interface).to receive(:get_current_installed_keys) do |username, type, public_keyring, secret_keyring|
          @current_key_checks << {
              :type => type,
              :username => username,
              :keyring_public => public_keyring,
              :keyring_secret => secret_keyring
          }
          current
        end
        allow(@gpg_interface).to receive(:get_key_header) do |base64|
          @base64_used = base64
          draft
        end
        allow(@gpg_interface).to receive(:import_trust) do |username, base64, public_keyring, secret_keyring|
          @keytrusts_imported << {
              :base64 => base64,
              :keyring_public => public_keyring,
              :keyring_secret => secret_keyring,
              :username => username
          }
          draft
        end
        allow(@gpg_interface).to receive(:import_keys) do |username, base64, public_keyring, secret_keyring|
          @keys_imported << {
              :base64 => base64,
              :keyring_public => public_keyring,
              :keyring_secret => secret_keyring,
              :username => username
          }
          draft
        end
        allow(@gpg_interface).to receive(:delete_keys) do |username, key_header_to_delete, public_keyring, secret_keyring|
          @keys_deleted << {
              :username => username,
              :keyring_public => public_keyring,
              :keyring_secret => secret_keyring,
              :key_header => key_header_to_delete
          }
        end
      end

      def executed_command_lines
        @shell_outs.inject({}) do |total, item|
          total[item.command] = item.input
          total
        end
      end
    end
  end
end