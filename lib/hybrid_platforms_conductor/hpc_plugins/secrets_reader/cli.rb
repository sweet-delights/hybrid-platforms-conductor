require 'hybrid_platforms_conductor/secrets_reader'

module HybridPlatformsConductor

  module HpcPlugins

    module SecretsReader

      # Get secrets from the command-line
      class Cli < HybridPlatformsConductor::SecretsReader

        # Constructor
        #
        # Parameters::
        # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
        # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
        # * *config* (Config): Config to be used. [default: Config.new]
        # * *cmd_runner* (CmdRunner): CmdRunner to be used. [default: CmdRunner.new]
        # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default: NodesHandler.new]
        def initialize(
          logger: Logger.new($stdout),
          logger_stderr: Logger.new($stderr),
          config: Config.new,
          cmd_runner: CmdRunner.new,
          nodes_handler: NodesHandler.new
        )
          super
          @secrets_files = []
        end

        # Complete an option parser with options meant to control this secrets reader
        # [API] - This method is optional
        #
        # Parameters::
        # * *options_parser* (OptionParser): The option parser to complete
        def options_parse(options_parser)
          options_parser.on('-e', '--secrets JSON_FILE', 'Specify a secrets location from a local JSON file. Can be specified several times.') do |file|
            @secrets_files << file
          end
        end

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
        def secrets_for(_node, _service)
          # As we are dealing with global secrets, cache the reading for performance between nodes and services.
          unless defined?(@secrets)
            @secrets = {}
            @secrets_files.each do |secrets_file|
              raise "Missing secrets file: #{secrets_file}" unless File.exist?(secrets_file)

              @secrets.merge!(JSON.parse(File.read(secrets_file))) do |key, value_1, value_2|
                raise "Secret #{key} has conflicting values between different secret JSON files." if value_1 != value_2

                value_1
              end
            end
          end
          @secrets
        end

      end

    end

  end

end
