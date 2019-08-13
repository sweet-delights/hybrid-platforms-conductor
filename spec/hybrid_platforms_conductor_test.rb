require 'fileutils'
require 'tmpdir'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/platform_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/ssh_executor'

module HybridPlatformsConductorTest

  class TestPlatformHandler < HybridPlatformsConductor::PlatformHandler

    class << self

      # Platform properties, per platform name. Properties can be:
      # * *nodes* (Hash< String, Hash<Symbol,Object> >): List of nodes, and their associated info (per node name) [default: {}]:
      #   * *meta* (Hash<String,Object>): JSON object storing metadata about this node
      #   * *service* (String): Service bound to this node
      # * *nodes_lists* (Hash< String, Array< String > >): Nodes lists, per list name [default: {}]
      # Hash<String, Hash<Symbol,Object> >
      attr_accessor :platforms_info

      # Reset variables, so that they don't interfere between tests
      def reset
        @platforms_info = {}
      end

    end

    self.reset

    # Get the list of known hostnames.
    # [API] - This method is mandatory.
    #
    # Result::
    # * Array<String>: List of hostnames
    def known_hostnames
      platform_info[:nodes].keys
    end

    # Get the list of known host list names
    # [API] - This method is optional.
    #
    # Result::
    # * Array<String>: List of hosts list names
    def known_hosts_lists
      platform_info[:nodes_lists].keys
    end

    # Get the list of host descriptions belonging to a hosts list
    # [API] - This method is optional unless known_hosts_lists has been defined.
    #
    # Parameters::
    # * *nodes_list_name* (String): Name of the nodes list
    # Result::
    # * Array<Object>: List of host descriptions
    def hosts_desc_from_list(nodes_list_name)
      platform_info[:nodes_lists][nodes_list_name]
    end

    # Get the configuration of a given hostname.
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): Node to read configuration from
    # Result::
    # * Hash<String,Object>: The corresponding JSON configuration
    def node_conf_for(node)
      node_info(node)[:meta]
    end

    # Return the service for a given node
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * String: The corresponding service
    def service_for(node)
      node_info(node)[:service]
    end

    # Get the default gateway name to be used for a given hostname.
    # [API] - This method is optional.
    #
    # Parameters::
    # * *node* (String): Hostname we want to connect to.
    # * *ip* (String or nil): IP of the hostname we want to use for connection (or nil if no IP information given).
    # Result::
    # * String or nil: Name of the gateway (should be defined by the gateways configurations), or nil if no gateway.
    def default_gateway_for(node, ip)
      node_info(node)[:default_gateway]
    end

    private

    # Return the platform info
    #
    # Result::
    # * Hash<Symbol, Object>: Platform info (check TestPlatformHandler#platforms_info to know about properties)
    def platform_info
      {
        nodes: {},
        nodes_lists: {},
      }.merge(TestPlatformHandler.platforms_info[info[:repo_name]])
    end

    # Return the node info of a given node
    #
    # Parameters::
    # * *node* (String): Node to get infor for
    # Result::
    # * Hash<Symbol, Object>: Platform info (check TestPlatformHandler#platforms_info to know about properties)
    def node_info(node)
      platform_info[:nodes][node]
    end

  end

  # Helpers for the tests
  module Helpers

    # Setup a platforms.rb with a given content and call code when it's ready.
    # Automatically sets the ti_platforms env variable so that processes can then use it.
    # Clean-up at the end.
    #
    # Parameters::
    # * *content* (String): Platforms.rb's content
    # * Proc: Code called with the platforms.rb file created.
    def with_platforms(content)
      hybrid_platforms_dir = "#{Dir.tmpdir}/hpc_test/hybrid-platforms"
      FileUtils.mkdir_p hybrid_platforms_dir
      File.write("#{hybrid_platforms_dir}/platforms.rb", content)
      ENV['ti_platforms'] = hybrid_platforms_dir
      begin
        yield
      ensure
        FileUtils.rm_rf hybrid_platforms_dir
      end
    end

    # Setup several test repositories.
    # Clean-up at the end.
    #
    # Parameters::
    # * *names* (Array<String>): Name of the directories to be used [default = []]
    # * Proc: Code called with the repositories created.
    #   * Parameters::
    #     * *repositories* (Hash<String,String>): Path to the repositories, per repository name
    def with_repositories(names = [])
      repositories = Hash[names.map { |name| [name, "#{Dir.tmpdir}/hpc_test/#{name}"] }]
      repositories.values.each do |dir|
        FileUtils.mkdir_p dir
      end
      begin
        yield repositories
      ensure
        repositories.values.each do |dir|
          FileUtils.rm_rf dir
        end
      end
    end

    # Setup a test repository.
    # Clean-up at the end.
    #
    # Parameters::
    # * *name* (String): Name of the directory to be used [default = 'platform_repo']
    # * Proc: Code called with the repository created.
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_repository(name = 'platform_repo')
      with_repositories([name]) do |repositories|
        yield repositories[name]
      end
    end

    # Register the given platform handler classes
    #
    # Parameters::
    # * *platform_handlers* (Hash<Symbol,Class>): The platform handler classes, per platform type name
    def register_platform_handlers(platform_handlers)
      # Register a test plugin
      HybridPlatformsConductor::PlatformsDsl.instance_variable_set(:@platform_types, platform_handlers)
      # Reload the NodesHandler so that these new plugins are defined correctly among instance methods.
      load "#{__dir__}/../lib/hybrid_platforms_conductor/platforms_dsl.rb"
      load "#{__dir__}/../lib/hybrid_platforms_conductor/nodes_handler.rb"
    end

    # Instantiate a test environment with several test platforms, ready to run tests
    # Clean-up at the end.
    #
    # Parameters::
    # * *platforms_info* (Hash<Symbol,Object>): Platforms info for the test platform [default = {}]
    # * Proc: Code called with the environment ready
    #   * Parameters::
    #     * *repositories* (Hash<String,String>): Path to the repositories, per repository name
    def with_test_platforms(platforms_info = {})
      with_repositories(platforms_info.keys) do |repositories|
        with_platforms(repositories.values.map { |dir| "test_platform path: '#{dir}'" }.join("\n")) do
          register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
          HybridPlatformsConductorTest::TestPlatformHandler.platforms_info = platforms_info
          yield repositories
          HybridPlatformsConductorTest::TestPlatformHandler.reset
        end
      end
    end

    # Instantiate a test environment with a test platform handler, ready to run tests
    # Clean-up at the end.
    #
    # Parameters::
    # * *platform_info* (Hash<Symbol,Object>): Platform info for the test platform [default = {}]
    # * Proc: Code called with the environment ready
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_test_platform(platform_info = {})
      with_test_platforms('platform' => platform_info) do |repositories|
        yield repositories['platform']
      end
    end

    # Get expected commands for SSH connections established for a given set of nodes.
    # Those expected commands are meant to be directed and mocked by CmdRunner.
    #
    # Parameters::
    # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name:
    #   * *connection* (String): Connection string (fqdn, IP...) used by SSH
    #   * *user* (String): User used by SSH
    #   * *times* (Integer): Number of times this connection should be used [default: 1]
    # Result::
    # * Array< [String or Regexp, Proc] >: The expected commands that should be used, and their corresponding mocked code
    def ssh_expected_commands_for(nodes_connections)
      nodes_connections.map do |node, node_connection_info|
        node_connection_info[:times] = 1 unless node_connection_info.key?(:times)
        [
          [
            "ssh-keyscan #{node_connection_info[:connection]}",
            proc { [0, 'fake_host_key', ''] }
          ],
          [
            /^ssh-keygen -R #{Regexp.escape(node_connection_info[:connection])} -f .+\/known_hosts$/,
            proc { [0, '', ''] }
          ],
          [
            /^.+\/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} true$/,
            proc { [0, '', ''] }
          ],
          [
            /^.+\/ssh -O exit #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} 2>&1 | grep -v 'Exit request sent.'$/,
            proc { [1, '', ''] }
          ]
        ] * node_connection_info[:times]
      end.flatten(1)
    end

    # Return the expected Regexp a remote Bash command run by SSH Executor should be
    #
    # Parameters::
    # * *command* (String): The command to be run
    # * *node* (String): Node on which the command is run [default: 'node']
    # * *user* (String): User used to run the command [default: 'user']
    # Result::
    # * Regexp: The regexp that would match the SSH command run by CmdRunner
    def remote_bash_for(command, node: 'node', user: 'user')
      /^.+\/ssh #{Regexp.escape(user)}@hpc.#{Regexp.escape(node)} \/bin\/bash <<'EOF'\n#{Regexp.escape(command)}\nEOF$/
    end

    # Run some code with some expected commands to be run by CmdRunner.
    # Run expectations on the expected commands to be called.
    #
    # Parameters::
    # * *commands* (nil or Array< [String or Regexp, Proc] >): Expected commands that should be called on CmdRunner: the command name or regexp and the corresponding mocked code, or nil if no mocking to be done [default: nil]
    # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name (check ssh_expected_commands_for to know about properties) [default: {}]
    # * Proc: Code called to mock behaviour
    #   * Parameters::
    #     * Same parameters as CmdRunner@run_cmd
    def with_cmd_runner_mocked(commands: nil, nodes_connections: {})
      # Mock the calls to CmdRunner made by the SSH connections
      unexpected_commands = []
      unless commands.nil?
        remaining_expected_commands = ssh_expected_commands_for(nodes_connections) + commands
        allow(test_cmd_runner).to receive(:run_cmd) do |cmd, log_to_file: nil, log_to_stdout: true, expected_code: 0, timeout: nil, no_exception: false|
          # Check the remaining expected commands
          found_command = nil
          found_command_code = nil
          remaining_expected_commands.delete_if do |(expected_command, command_code)|
            break unless found_command.nil?
            if (expected_command.is_a?(String) && expected_command == cmd) || (expected_command.is_a?(Regexp) && cmd =~ expected_command)
              found_command = expected_command
              found_command_code = command_code
              true
            end
          end
          if found_command
            logger.debug "[ Mocked CmdRunner ] - Calling mocked command #{cmd}"
            found_command_code.call cmd, log_to_file: log_to_file, log_to_stdout: log_to_stdout, expected_code: expected_code, timeout: timeout, no_exception: no_exception
          else
            logger.error "[ Mocked CmdRunner ] - !!! Unexpected command run: #{cmd}"
            unexpected_commands << cmd
            [:unexpected_command_to_mock, '', "Could not mock unexpected command #{cmd}"]
          end
        end
      end
      yield
      expect(unexpected_commands).to eq []
      expect(remaining_expected_commands).to eq([]), "Expected CmdRunner commands were not run:\n#{remaining_expected_commands.map(&:first).join("\n")}" unless commands.nil?
    end

    # Get a test NodesHandler
    #
    # Result::
    # * NodesHandler: NodesHandler on which we can do testing
    def test_nodes_handler
      @nodes_handler = HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger unless @nodes_handler
      @nodes_handler
    end

    # Get a test CmdRunner
    #
    # Result::
    # * NodesHandler: NodesHandler on which we can do testing
    def test_cmd_runner
      @cmd_runner = HybridPlatformsConductor::CmdRunner.new logger: logger, logger_stderr: logger unless @cmd_runner
      @cmd_runner
    end

    # Get a test SshExecutor
    #
    # Result::
    # * SshExecutor: SshExecutor on which we can do testing
    def test_ssh_executor
      @ssh_executor = HybridPlatformsConductor::SshExecutor.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler unless @ssh_executor
      @ssh_executor
    end

    # Make sure the tested components are being reset before each test case
    RSpec.configure do |config|
      config.before(:each) do
        @nodes_handler = nil
        @cmd_runner = nil
        @ssh_executor = nil
        ENV.delete 'ti_gateways_conf'
        ENV.delete 'ti_gateways_user'
        ENV.delete 'platforms_ssh_user'
      end
    end

    private

    # Get the logger for tests
    #
    # Result::
    # * Logger: The logger to be used
    def logger
      if ENV['TEST_DEBUG'] == '1'
        logger = Logger.new(STDOUT)
        logger.level = Logger::DEBUG
        logger
      else
        Logger.new('/dev/null')
      end
    end

  end

end
