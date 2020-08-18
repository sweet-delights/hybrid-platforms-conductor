require 'hybrid_platforms_conductor/provisioner'

module HybridPlatformsConductor

  module HpcPlugins

    module Provisioner

      # Provision Podman containers
      class Podman < HybridPlatformsConductor::Provisioner

        # Create an instance.
        # Reuse an existing one if it already exists.
        # [API] - This method is mandatory
        def create
          # Get the image name for this node
          image = @nodes_handler.get_image_of(@node).to_sym
          # Find if we have such an image registered
          if @nodes_handler.known_os_images.include?(image)
            # Build the image if it does not exist
            image_tag = "hpc_image_#{image}"
            image_futex_file = "#{Dir.tmpdir}/hpc_podman_image_futexes/#{image_tag}"
            FileUtils.mkdir_p File.dirname(image_futex_file)
            Futex.new(image_futex_file).open do
              @cmd_runner.run_cmd "cd #{@nodes_handler.os_image_dir(image)} && #{podman_cmd} build --tag #{image_tag} --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs ."
            end
            container_name = "hpc_container_#{@node}_#{@environment}"
            container_futex_file = "#{Dir.tmpdir}/hpc_podman_container_futexes/#{image_tag}"
            FileUtils.mkdir_p File.dirname(container_futex_file)
            Futex.new(container_futex_file).open do
              _exit_status, stdout, _stderr = @cmd_runner.run_cmd "#{podman_cmd} container list --all | grep #{container_name}", expected_code: [0, 1]
              existing_container = !stdout.strip.empty?
              @cmd_runner.run_cmd "#{podman_cmd} container create --name #{container_name} #{image_tag}" unless existing_container
              @container = container_name
            end
          else
            raise "[ #{@node}/#{@environment} ] - Unknown Docker image #{image} defined for node #{@node}"
          end
        end

        # Start an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def start
          log_debug "[ #{@node}/#{@environment} ] - Start Podman Container #{@container} ..."
          @cmd_runner.run_cmd "#{podman_cmd} container start --cgroup-manager=cgroupfs #{@container}"
        end

        # Stop an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def stop
          log_debug "[ #{@node}/#{@environment} ] - Stop Podman Container #{@container} ..."
          @cmd_runner.run_cmd "#{podman_cmd} container stop #{@container}"
        end

        # Destroy an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def destroy
          log_debug "[ #{@node}/#{@environment} ] - Destroy Podman Container #{@container} ..."
          @cmd_runner.run_cmd "#{podman_cmd} container rm #{@container}"
        end

        # Returns the state of an instance
        # [API] - This method is mandatory
        #
        # Result::
        # * Symbol: The state the instance is in. Possible values are:
        #   * *:missing*: The instance does not exist
        #   * *:created*: The instance has been created but is not running
        #   * *:running*: The instance is running
        #   * *:exited*: The instance has run and is now stopped
        #   * *:error*: The instance is in error
        def state
          if !defined?(@container) || @container.nil?
            :missing
          else
            begin
              _exit_status, stdout, _stderr = @cmd_runner.run_cmd "#{podman_cmd} inspect #{@container}"
              status = JSON.parse(stdout).first['State']['Status'].to_sym
              status = :created if status == :configured
              status
            rescue
              log_warn "Error while reading state of Podman container #{@container}: #{$!}"
              :error
            end
          end
        end

        # Return the IP address of an instance.
        # Prerequisite: create has been called before.
        # [API] - This method is optional
        #
        # Result::
        # * String or nil: The instance IP address, or nil if this information is not relevant
        def ip
          # Get its IP that could have changed upon restart
          # cf https://github.com/moby/moby/issues/2801
          # Make sure we refresh its info before querying it, as we could hit a cache of a previous IP.
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd "#{podman_cmd} container inspect #{@container} | grep IPAddress"
          stdout.strip.match(/\d+\.\d+\.\d+\.\d+/)[0]
        end

        private

        # Get the Podman command.
        # Handle sudo rights if needed.
        #
        # Result::
        # * String: The Podman command
        def podman_cmd
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd 'whoami'
          stdout.strip == 'root' ? 'podman' : 'sudo podman'
        end

      end

    end

  end

end
