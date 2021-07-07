require 'base64'
require 'nokogiri'
require 'tempfile'
require 'keepass_kpscript'
require 'zlib'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/safe_merge'
require 'hybrid_platforms_conductor/secrets_reader'

module HybridPlatformsConductor

  module HpcPlugins

    module SecretsReader

      # Get secrets from a KeePass database
      class Keepass < HybridPlatformsConductor::SecretsReader

        include SafeMerge
        include Credentials

        # Extend the Config DSL
        module ConfigDSLExtension

          # List of defined KeePass secrets. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
          # * *database* (String): Database file path.
          # * *group_path* (Array<String>): Group path to extract from.
          # Array< Hash<Symbol, Object> >
          attr_reader :keepass_secrets

          # String: The KPScript command line
          attr_reader :kpscript

          # Mixin initializer
          def init_keepass_config
            @keepass_secrets = []
            @kpscript = nil
          end

          # Set the KPScript command line
          #
          # Parameters::
          # * *cmd* (String): KPScript command line
          def use_kpscript_from(cmd)
            @kpscript = cmd
          end

          # Set a KeePass database configuration
          #
          # Parameters::
          # * *database* (String): Database file path.
          # * *group_path* (Array<String>): Group path to extract from [default: []].
          def secrets_from_keepass(database:, group_path: [])
            @keepass_secrets << {
              nodes_selectors_stack: current_nodes_selectors_stack,
              database: database,
              group_path: group_path
            }
          end

        end

        Config.extend_config_dsl_with ConfigDSLExtension, :init_keepass_config

        # Return secrets for a given service to be deployed on a node.
        # [API] - This method is mandatory
        # [API] - The following API components are accessible:
        # * *@config* (Config): Main configuration API.
        # * *@cmd_runner* (CmdRunner): Command Runner API.
        # * *@nodes_handler* (NodesHandler): Nodes handler API.
        #
        # Parameters::
        # * *node* (String): Node to be deployed
        # * *service* (String): Service to be deployed
        # Result::
        # * Hash: The secrets
        def secrets_for(node, service)
          secrets = {}
          # As we are dealing with global secrets, cache the reading for performance between nodes and services.
          # Keep secrets cache grouped by URL/ID
          @secrets = {} unless defined?(@secrets)
          @nodes_handler.select_confs_for_node(node, @config.keepass_secrets).each do |keepass_secrets_info|
            secret_id = "#{keepass_secrets_info[:database]}:#{keepass_secrets_info[:group_path].join('/')}"
            unless @secrets.key?(secret_id)
              raise 'Missing KPScript configuration. Please use use_kpscript_from to set it.' if @config.kpscript.nil?

              with_credentials_for(:keepass, resource: keepass_secrets_info[:database]) do |_user, password|
                Tempfile.create('hpc_keepass') do |xml_file|
                  key_file = ENV['hpc_key_file_for_keepass']
                  password_enc = ENV['hpc_password_enc_for_keepass']
                  keepass_credentials = {}
                  keepass_credentials[:password] = password.to_unprotected if password
                  keepass_credentials[:password_enc] = password_enc if password_enc
                  keepass_credentials[:key_file] = key_file if key_file
                  KeepassKpscript.
                    use(@config.kpscript, debug: log_debug?).
                    open(keepass_secrets_info[:database], **keepass_credentials).
                    export('KeePass XML (2.x)', xml_file.path, group_path: keepass_secrets_info[:group_path].empty? ? nil : keepass_secrets_info[:group_path])
                  @secrets[secret_id] = parse_xml_secrets(Nokogiri::XML(xml_file).at_xpath('KeePassFile/Root/Group'))
                end
              end
            end
            conflicting_path = safe_merge(secrets, @secrets[secret_id])
            raise "Secret set at path #{conflicting_path.join('->')} by #{keepass_secrets_info[:database]}#{keepass_secrets_info[:group_path].empty? ? '' : " from group #{keepass_secrets_info[:group_path].join('/')}"} for service #{service} on node #{node} has conflicting values (#{log_debug? ? "#{@secrets[secret_id].dig(*conflicting_path)} != #{secrets.dig(*conflicting_path)}" : 'set debug for value details'})." unless conflicting_path.nil?
          end
          secrets
        end

        private

        # List of fields to include in the secrets and their corresponding XML name
        FIELDS = {
          notes: 'Notes',
          password: 'Password',
          url: 'URL',
          user_name: 'UserName'
        }

        # Parse XML secrets from a Nokogiri XML group node
        #
        # Parameters::
        # * *group* (Nokogiri::XML::Element): The group to parse
        # Result::
        # * Hash: The JSON secrets parsed from this group
        def parse_xml_secrets(group)
          # Parse all entries
          group.xpath('Entry').map do |entry|
            [
              entry.at_xpath('String/Key[contains(.,"Title")]/../Value').text,
              FIELDS.map do |property, field|
                value = entry.at_xpath("String/Key[contains(.,\"#{field}\")]/../Value")&.text
                if value.nil? || value.empty?
                  nil
                else
                  [
                    property.to_s,
                    value
                  ]
                end
              end.compact.to_h.merge(
                entry.xpath('Binary').map do |binary|
                  binary_meta = group.document.at_xpath("KeePassFile/Meta/Binaries/Binary[@ID=#{Integer(binary.xpath('Value').attr('Ref').value)}]")
                  binary_content = Base64.decode64(binary_meta.text)
                  if binary_meta.attr('Compressed') == 'True'
                    gz = Zlib::GzipReader.new(StringIO.new(binary_content))
                    binary_content = gz.read
                    gz.close
                  end
                  [
                    binary.xpath('Key').text,
                    binary_content
                  ]
                end.to_h
              )
            ]
          end.to_h.merge(
            # Add children groups
            group.xpath('Group').map do |sub_group|
              [
                sub_group.at_xpath('Name').text,
                parse_xml_secrets(sub_group)
              ]
            end.to_h
          )
        end

      end

    end

  end

end
