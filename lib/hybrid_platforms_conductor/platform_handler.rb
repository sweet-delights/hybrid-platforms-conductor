require 'json'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Common ancestor to any platform handler
  class PlatformHandler < Plugin

    # Make it so that we can sort lists of platforms
    include Comparable

    # Callback called when a subclass inherits this class.
    #
    # Parameters::
    # * *subclass* (Class): The inheriting class
    def self.inherited(subclass)
      # Make sure we define automatically a helper for such a platform
      mixin = Module.new
      platform_type = subclass.name.split('::').last.gsub(/([a-z\d])([A-Z\d])/, '\1_\2').downcase.to_sym
      mixin.define_method("#{platform_type}_platform".to_sym) do |path: nil, git: nil, branch: 'master', &platform_config_code|
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
                git_repo = Git.init(local_repository_path)
                git_repo.add_remote('origin', git).fetch(ref: "#{branch}:#{local_ref}")
                git_repo.checkout local_ref
              end
            end
            local_repository_path
          else
            raise 'The platform has to be defined with either a path or a git URL'
          end
        @platform_dirs[platform_type] = [] unless @platform_dirs.key?(platform_type)
        @platform_dirs[platform_type] << repository_path
        platform_config_code&.call(repository_path)
      end
      # Register this new mixin in the Config DSL
      extend_config_dsl_with(mixin)
      super
    end

    # Repository path
    #   String
    attr_reader :repository_path

    # Platform type
    #   Symbol
    attr_reader :platform_type

    # Before deploying, need to set some components in case the plugins need them
    attr_accessor :nodes_handler, :actions_executor

    # Constructor
    #
    # Parameters::
    # * *platform_type* (Symbol): Platform type
    # * *repository_path* (String): Repository path
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    def initialize(
      platform_type,
      repository_path,
      logger: Logger.new($stdout),
      logger_stderr: Logger.new($stderr),
      config: Config.new,
      cmd_runner: CmdRunner.new
    )
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @platform_type = platform_type
      @repository_path = repository_path
      @cmd_runner = cmd_runner
      init if respond_to?(:init)
    end

    # Return the name of the platform
    #
    # Result::
    # * String: Name of the platform
    def name
      info[:repo_name]
    end

    # Get the list of impacted nodes and services from a files diff.
    # [API] - This is the default implementation, and is meant to be overriden by Platform Handlers.
    #
    # Parameters::
    # * *files_diffs* (Hash< String, Hash< Symbol, Object > >): List of diffs info, per file name having a diff. Diffs info have the following properties:
    #   * *moved_to* (String): The new file path, in case it has been moved [optional]
    #   * *diff* (String): The diff content
    # Result::
    # * Array<String>: The list of nodes impacted by this diff
    # * Array<String>: The list of services impacted by this diff
    # * Boolean: Are there some files that have a global impact (meaning all nodes are potentially impacted by this diff)?
    def impacts_from(_files_diffs)
      # By default, consider all nodes of the platform are impacted by whatever diff.
      [
        [],
        [],
        true
      ]
    end

    # Get some information from this platform.
    # This information identifies the code level that is currently checked out.
    #
    # Result::
    # * Hash<Symbol,Object>: Description of this platform:
    #   * *repo_name* (String): The repository name
    #   * *commit* (Hash<Symbol,Object>): Information on the checked out Git commit
    #     * *id* (String): Commit ID
    #     * *ref* (String): Associated reference
    #     * *message* (String): Associated message
    #     * *date* (Time): Commit date in UTC
    #     * *author* (Hash<Symbol,Object>): Information on the author:
    #       * *name* (String): Name of the commit author
    #       * *email* (String): Email of the commit author
    #  * *status* (Hash<Symbol,Object>): Information on the checked out Git status
    #    * *changed_files* (Array<String>): List of changed files
    #    * *added_files* (Array<String>): List of added files
    #    * *deleted_files* (Array<String>): List of deleted files
    #    * *untracked_files* (Array<String>): List of untracked files
    def info
      # Keep info in a memory cache, so that we don't query git for nothing
      unless defined?(@info)
        git = nil
        begin
          git = Git.open(@repository_path)
        rescue
          log_debug "Platform #{@repository_path} is not a git repository"
        end
        @info =
          if git
            git_status = git.status
            git_commit = git.log.first
            {
              repo_name: git.remotes.empty? ? File.basename(@repository_path) : File.basename(git.remotes.first.url).gsub(/\.git$/, ''),
              commit: {
                id: git_commit.sha,
                ref: git_commit.name,
                message: git_commit.message,
                date: git_commit.date.utc,
                author: {
                  name: git_commit.author.name,
                  email: git_commit.author.email
                }
              },
              status: {
                changed_files: git_status.changed.keys,
                added_files: git_status.added.keys,
                deleted_files: git_status.deleted.keys,
                untracked_files: git_status.untracked.keys
              }
            }
          else
            {
              repo_name: File.basename(@repository_path)
            }
          end
      end
      @info
    end

    # Order relation
    #
    # Parameters::
    # * *other* (Object): Other object to compare to
    # Result::
    # * Integer: -1, 0, or +1 depending on whether the receiver is less than, equal to, or greater than the other object
    def <=>(other)
      if other.is_a?(PlatformHandler)
        name <=> other.name
      else
        super
      end
    end

  end

end
