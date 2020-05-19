require 'json'

module HybridPlatformsConductor

  # Common ancestor to any platform handler
  class PlatformHandler

    # Make it so that we can sort lists of platforms
    include Comparable

    include LoggerHelpers

    # Repository path
    #   String
    attr_reader :repository_path

    # Platform type
    #   Symbol
    attr_reader :platform_type

    # Before deploying, need to set the command runner and Actions Executor in case the plugins need them
    attr_accessor :cmd_runner, :actions_executor

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *platform_type* (Symbol): Platform type
    # * *repository_path* (String): Repository path
    # * *nodes_handler* (NodesHandler): Nodes handler that can be used to get info about nodes.
    def initialize(logger, logger_stderr, platform_type, repository_path, nodes_handler)
      @logger = logger
      @logger_stderr = logger_stderr
      @platform_type = platform_type
      @repository_path = repository_path
      @nodes_handler = nodes_handler
      self.init if self.respond_to?(:init)
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
          log_warn "Platform #{@repository_path} is not a git repository"
        end
        @info =
          if git
            git_status = git.status
            git_commit = git.log.first
            {
              repo_name: File.basename(git.remotes.first.url).gsub(/\.git$/, ''),
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
        info[:repo_name] <=> other.info[:repo_name]
      else
        super
      end
    end

    # Get platforms handled by HPCs Conductor specific metadata for this platform, if any.
    #
    # Result::
    # * Hash<String,String>: The metadata information (keys are optional):
    #   * *test* (Hash<String,String>): All information regarding testing this platform:
    #     * *expected_failures* (Hash< String, Hash< String, String> >): Expected failure message, per node name, per test name.
    def metadata
      metadata_file = "#{@repository_path}/hpc.json"
      if File.exist?(metadata_file)
        JSON.parse(File.read(metadata_file))
      else
        {}
      end
    end

  end

end
