module HybridPlatformsConductor

  module Actions

    # Copy files and directories from the local host to the remote one
    class Scp < Action

      # Setup the action
      #
      # Parameters::
      # * *mappings* (Hash<String or Symbol, Object>): Set of couples source => destination_dir to copy files or directories from the local file system to the remote file system.
      #   The following properties can also be used:
      #   * *sudo* (Boolean): Do we use sudo to make the copy? [default: false]
      #   * *owner* (String or nil): Owner to use for files, or nil to use current one [default: nil]
      #   * *group* (String or nil): Group to use for files, or nil to use current one [default: nil]
      def setup(mappings)
        @mappings = mappings
        @sudo = @mappings.delete(:sudo) || false
        @owner = @mappings.delete(:owner)
        @group = @mappings.delete(:group)
      end

      # Execute the action
      def execute
        @mappings.each do |scp_from, scp_to_dir|
          log_debug "[#{@node}] - Copy over SSH \"#{scp_from}\" => \"#{scp_to_dir}\""
          with_ssh_to_node do |ssh_exec, ssh_url|
            run_cmd <<~EOS
              cd #{File.dirname(scp_from)} && \
              tar \
                --create \
                --gzip \
                --file - \
                #{@owner.nil? ? '' : "--owner #{@owner}"} \
                #{@group.nil? ? '' : "--group #{@group}"} \
                #{File.basename(scp_from)} | \
              #{ssh_exec} \
                #{ssh_url} \
                \"#{@sudo ? 'sudo ' : ''}tar \
                  --extract \
                  --gunzip \
                  --file - \
                  --directory #{scp_to_dir} \
                  --owner root \
                \"
            EOS
          end
        end
      end

    end

  end

end
