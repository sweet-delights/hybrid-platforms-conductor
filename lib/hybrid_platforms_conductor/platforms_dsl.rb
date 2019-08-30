require 'erb'
require 'git'

module HybridPlatformsConductor

  # Provide the DSL that can be used in platforms configuration files
  module PlatformsDsl

    # Get the list of available platform handler plugins
    #
    # Result::
    # * Hash< Symbol, Class >: The list of types plugins, with their associated class
    def self.platform_types
      # Look for platform types plugins, directly from what is included by the Gemfile to avoid repetitions of their declarations.
      @platform_types = Hash[Gem.
        loaded_specs.
        keys.
        map { |gem_name| gem_name =~ /^hybrid_platforms_conductor-(.+)$/ ? $1.to_sym : nil }.
        compact.
        map do |type_name|
          require "hybrid_platforms_conductor/platform_handlers/#{type_name}"
          [
            type_name,
            HybridPlatformsConductor::PlatformHandlers.const_get(type_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end] unless defined?(@platform_types)
      @platform_types
    end

    # Initialize the module variables
    def initialize_platforms_dsl
      # Directory in which platforms are cloned
      @git_platforms_dir = "#{hybrid_platforms_dir}/cloned_platforms"
      # Read platforms file
      self.instance_eval(File.read("#{hybrid_platforms_dir}/platforms.rb"))
    end

    # Dynamically define the platform methods allowing to register a new platform.
    # They are named <plugin_name>_platform.
    self.platform_types.each do |platform_type, platform_handler_class|

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
        # Register all known hostnames for this platform
        platform_handler.known_nodes.each do |hostname|
          raise "Can't register #{hostname} to platform #{repository_path}, as it is already defined in platform #{@nodes_platform[hostname].repository_path}." if @nodes_platform.key?(hostname)
          @nodes_platform[hostname] = platform_handler
        end
        # Register all known hosts list
        platform_handler.known_nodes_lists.each do |hosts_list_name|
          raise "Can't register hosts list #{hosts_list_name} to platform #{repository_path}, as it is already defined in platform #{@nodes_list_platform[hosts_list_name].repository_path}." if @nodes_list_platform.key?(hosts_list_name)
          @nodes_list_platform[hosts_list_name] = platform_handler
        end if platform_handler.respond_to?(:known_nodes_lists)
      end

    end

    # Register a new gateway configuration
    #
    # Parameters::
    # * *gateway_conf* (Symbol): Name of the gateway configuration
    # * *ssh_def_erb* (String): Corresponding SSH ERB configuration
    def gateway(gateway_conf, ssh_def_erb)
      raise "Gateway #{gateway_conf} already defined to #{@gateways[gateway_conf]}" if @gateways.key?(gateway_conf)
      @gateways[gateway_conf] = ssh_def_erb
    end

    # Register a new Docker image
    #
    # Parameters::
    # * *image* (Symbol): Name of the Docker image
    # * *dir* (String): Directory containing the Dockerfile defining the image
    def docker_image(image, dir)
      raise "Docker image #{image} already defined to #{@docker_images[image]}" if @docker_images.key?(image)
      @docker_images[image] = dir
    end

  end

end
