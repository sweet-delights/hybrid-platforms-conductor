module HybridPlatformsConductorTest

  module Helpers

    module NodesHandlerHelpers

      # Setup several test repositories.
      # Clean-up at the end.
      #
      # Parameters::
      # * *names* (Array<String>): Name of the directories to be used [default = []]
      # * *as_git* (Boolean): Do we initialize those repositories as Git repositories? [default: false]
      # * Proc: Code called with the repositories created.
      #   * Parameters::
      #     * *repositories* (Hash<String,String>): Path to the repositories, per repository name
      def with_repositories(names = [], as_git: false)
        repositories = Hash[names.map { |name| [name, "#{Dir.tmpdir}/hpc_test/#{name}"] }]
        repositories.values.each do |dir|
          FileUtils.rm_rf dir
          FileUtils.mkdir_p dir
          if as_git
            git = Git.init(dir)
            FileUtils.touch("#{dir}/test_file")
            git.add('test_file')
            git.config('user.name', 'Thats Me')
            git.config('user.email', 'email@email.com')
            git.commit('Test commit')
            git.add_remote('origin', "https://my_remote.com/path/to/#{File.basename(dir)}.git")
          end
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
      # * *as_git* (Boolean): Do we initialize those repositories as Git repositories? [default: false]
      # * Proc: Code called with the repository created.
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_repository(name = 'platform_repo', as_git: false)
        with_repositories([name], as_git: as_git) do |repositories|
          yield repositories[name]
        end
      end

      # Setup a platforms.rb with a given content and call code when it's ready.
      # Automatically sets the hpc_platforms env variable so that processes can then use it.
      # Clean-up at the end.
      #
      # Parameters::
      # * *content* (String): Platforms.rb's content
      # * Proc: Code called with the platforms.rb file created.
      #   * Parameters::
      #     * *hybrid_platforms_dir* (String): The hybrid-platforms directory
      def with_platforms(content)
        with_repository('hybrid-platforms') do |hybrid_platforms_dir|
          File.write("#{hybrid_platforms_dir}/platforms.rb", content)
          ENV['hpc_platforms'] = hybrid_platforms_dir
          yield hybrid_platforms_dir
        end
      end

      # Instantiate a test environment with several test platforms, ready to run tests
      # Clean-up at the end.
      #
      # Parameters::
      # * *platforms_info* (Hash<String,Object>): Platforms info for the test platform [default = {}]
      # * *as_git* (Boolean): Do we initialize those repositories as Git repositories? [default = false]
      # * *additional_platforms_content* (String): Additional platforms content to be added [default = '']
      # * Proc: Code called with the environment ready
      #   * Parameters::
      #     * *repositories* (Hash<String,String>): Path to the repositories, per repository name
      def with_test_platforms(platforms_info = {}, as_git = false, additional_platforms_content = '')
        with_repositories(platforms_info.keys, as_git: as_git) do |repositories|
          platform_types = []
          with_platforms(repositories.map do |platform, dir|
            platform_type = platforms_info[platform].key?(:platform_type) ? platforms_info[platform][:platform_type] : :test
            platform_types << platform_type unless platform_types.include?(platform_type)
            "#{platform_type}_platform path: '#{dir}'"
          end.join("\n") + "\n#{additional_platforms_content}") do
            register_platform_handlers(Hash[platform_types.map { |platform_type| [platform_type, HybridPlatformsConductorTest::TestPlatformHandler] }])
            self.test_platforms_info = platforms_info
            yield repositories
          end
        end
      end

      # Instantiate a test environment with a test platform handler, ready to run tests
      # Clean-up at the end.
      #
      # Parameters::
      # * *platform_info* (Hash<Symbol,Object>): Platform info for the test platform [default = {}]
      # * *as_git* (Boolean): Do we initialize those repositories as Git repositories? [default = false]
      # * *additional_platforms_content* (String): Additional platforms content to be added [default = '']
      # * Proc: Code called with the environment ready
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_test_platform(platform_info = {}, as_git = false, additional_platforms_content = '')
        platform_name = as_git ? 'my_remote_platform' : 'platform'
        with_test_platforms({ platform_name => platform_info }, as_git, additional_platforms_content) do |repositories|
          yield repositories[platform_name]
        end
      end

      # Get a test NodesHandler
      #
      # Result::
      # * NodesHandler: NodesHandler on which we can do testing
      def test_nodes_handler
        @nodes_handler = HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner unless @nodes_handler
        @nodes_handler
      end

    end

  end

end
