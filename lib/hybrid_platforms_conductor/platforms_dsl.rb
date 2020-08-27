require 'git'
require 'hybrid_platforms_conductor/plugins'

module HybridPlatformsConductor

  # Provide the DSL that can be used in platforms configuration files
  module PlatformsDsl

    class << self

      # NodesHandler: A NodesHandler instance used to access platform handlers
      attr_accessor :nodes_handler

      # Array<Symbol>: List of mixin initializers to call
      attr_accessor :mixin_initializers

      # Define the helpers in the DSL for Platform Handlers
      # They are named <plugin_name>_platform.
      def define_platform_handler_helpers
        @nodes_handler.platform_types.each do |platform_type, platform_handler_class|

          # Register a new platform of type platform_type.
          # The platform can be taken from a local path, or from a git repository to be cloned.
          #
          # Parameters::
          # * *path* (String or nil): Path to a local repository where the platform is stored, or nil if not using this way to get it. [default: nil].
          # * *git* (String or nil): Git URL to fetch the repository where the platform is stored, or nil if not using this way to get it. [default: nil].
          # * *branch* (String): Git branch to clone from the Git repository. Used only if git is not nil. [default: 'master'].
          define_method("#{platform_type}_platform".to_sym) do |path: nil, git: nil, branch: 'master'|
            repository_path =
              if !path.nil?
                path
              elsif !git.nil?
                # Clone in a local repository
                local_repository_path = "#{@git_platforms_dir}/#{File.basename(git)[0..-File.extname(git).size - 1]}"
                unless File.exist?(local_repository_path)
                  branch = "refs/heads/#{branch}" unless branch.include?('/')
                  local_ref = "refs/remotes/origin/#{branch.split('/').last}"
                  section "Cloning #{git} (#{branch} => #{local_ref}) into #{local_repository_path}" do
                    git_repo = Git.init(local_repository_path, )
                    git_repo.add_remote('origin', git).fetch(ref: "#{branch}:#{local_ref}")
                    git_repo.checkout local_ref
                  end
                end
                local_repository_path
              else
                raise 'The platform has to be defined with either a path or a git URL'
              end
            platform_handler = platform_handler_class.new(@logger, @logger_stderr, platform_type, repository_path, self)
            @platform_handlers[platform_type] = [] unless @platform_handlers.key?(platform_type)
            @platform_handlers[platform_type] << platform_handler
            raise "Platform name #{platform_handler.info[:repo_name]} is declared several times." if @platforms.key?(platform_handler.info[:repo_name])
            @platforms[platform_handler.info[:repo_name]] = platform_handler
            # Register all known nodes for this platform
            platform_handler.known_nodes.each do |node|
              raise "Can't register #{node} to platform #{repository_path}, as it is already defined in platform #{@nodes_platform[node].repository_path}." if @nodes_platform.key?(node)
              @nodes_platform[node] = platform_handler
            end
            # Register all known nodes lists
            platform_handler.known_nodes_lists.each do |nodes_list|
              raise "Can't register nodes list #{nodes_list} to platform #{repository_path}, as it is already defined in platform #{@nodes_list_platform[nodes_list].repository_path}." if @nodes_list_platform.key?(nodes_list)
              @nodes_list_platform[nodes_list] = platform_handler
            end if platform_handler.respond_to?(:known_nodes_lists)
          end

        end
      end

    end
    @mixin_initializers = []

    # Initialize the module variables
    def initialize_platforms_dsl
      # Directory in which platforms are cloned
      @git_platforms_dir = "#{hybrid_platforms_dir}/cloned_platforms"
      PlatformsDsl.nodes_handler = self
      PlatformsDsl.define_platform_handler_helpers
      # Make sure plugins can decorate our DSL with their owns additions as well
      # Therefore we parse all possible plugin types
      Dir.glob("#{__dir__}/hpc_plugins/*").each do |plugin_dir|
        Plugins.new(File.basename(plugin_dir).to_sym, logger: @logger, logger_stderr: @logger_stderr)
      end
      # Call initializers if needed
      PlatformsDsl.mixin_initializers.each do |mixin_init_method|
        self.send(mixin_init_method)
      end
      # Read platforms file
      self.instance_eval(File.read("#{hybrid_platforms_dir}/platforms.rb"))
    end

    # Register a new OS image
    #
    # Parameters::
    # * *image* (Symbol): Name of the Docker image
    # * *dir* (String): Directory containing the Dockerfile defining the image
    def os_image(image, dir)
      raise "OS image #{image} already defined to #{@os_images[image]}" if @os_images.key?(image)
      @os_images[image] = dir
    end

  end

end
