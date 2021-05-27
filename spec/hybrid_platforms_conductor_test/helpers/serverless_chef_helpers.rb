require 'hybrid_platforms_conductor/hpc_plugins/platform_handler/serverless_chef'

module HybridPlatformsConductorTest

  module Helpers

    module ServerlessChefHelpers

      # Setup a platforms config using test repository names
      #
      # Parameters::
      # * *names* (String or Hash<String, String>): The test repository name (taken from the repositories/ folder), or a Hash of names and their corresponding test repository source name
      # * *additional_config* (String): Additional config to append after the platform declaration [default: '']
      # * *as_git* (Boolean): Should we initialize the repository as a git repo? [default: false]
      # * Proc: Code called when repository is setup
      #   * Parameters::
      #     If there was only 1 repository:
      #     * *platform* (PlatformHandler): The platform handler to be tested
      #     * *repository* (String): Repository path
      #     If there was multiple repositories:
      #     * *repositories* (Hash<PlatformHandler,String>): Set of repositories, per platform handler
      def with_serverless_chef_platforms(names, additional_config: '', as_git: false)
        names = { names => names } unless names.is_a?(Hash)
        with_repositories(names.keys, as_git: as_git) do |repositories|
          repositories.each do |name, repository|
            # Copy the content of the test repository in the temporary one
            FileUtils.cp_r "#{__dir__}/../serverless_chef_repositories/#{names[name]}/.", repository
          end
          with_platforms(repositories.values.map { |repository| "serverless_chef_platform path: '#{repository}'\n" }.join + additional_config) do
            repositories = Hash[names.keys.map do |name|
              [
                test_platforms_handler.platform(name),
                repositories[name]
              ]
            end]
            test_platforms_handler.inject_dependencies(
              nodes_handler: test_nodes_handler,
              actions_executor: test_actions_executor
            )
            if repositories.size == 1
              yield *repositories.first
            else
              yield repositories
            end
          end
        end
      end

    end

  end

end
