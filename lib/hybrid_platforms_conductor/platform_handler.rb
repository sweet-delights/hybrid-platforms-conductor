module HybridPlatformsConductor

  # Common ancestor to any platform handler
  class PlatformHandler

    # Repository path
    #   String
    attr_reader :repository_path

    # Platform type
    #   Symbol
    attr_reader :platform_type

    # Before deploying, need to set the command runner and SSH executor in case the plugins need them
    attr_accessor :cmd_runner, :ssh_executor

    # Constructor
    #
    # Parameters::
    # * *platform_type* (Symbol): Platform type
    # * *repository_path* (String): Repository path
    # * *nodes_handler* (NodesHandler): Nodes handler that can be used to get info about nodes.
    def initialize(platform_type, repository_path, nodes_handler)
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
    #  * *status* (Hash<Symbol,Object>): Information on the checked out Git status
    #    * *changed_files* (Array<String>): List of changed files
    #    * *added_files* (Array<String>): List of added files
    #    * *deleted_files* (Array<String>): List of deleted files
    #    * *untracked_files* (Array<String>): List of untracked files
    def info
      git = Git.open(@repository_path)
      git_status = git.status
      git_commit = git.log.first
      {
        repo_name: File.basename(git.remotes.first.url),
        commit: {
          id: git_commit.sha,
          ref: git_commit.name,
          message: git_commit.message,
          date: git_commit.date.utc
        },
        status: {
          changed_files: git_status.changed.keys,
          added_files: git_status.added.keys,
          deleted_files: git_status.deleted.keys,
          untracked_files: git_status.untracked.keys
        }
      }
    end

  end

end
