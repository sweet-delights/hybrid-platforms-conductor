require 'docker-api'
require 'hybrid_platforms_conductor/provisioner'

module HybridPlatformsConductor

  module HpcPlugins

    module Provisioner

      # Provision Docker containers
      class Docker < HybridPlatformsConductor::Provisioner

        # Are dependencies met before using this plugin?
        # [API] - This method is optional
        #
        # Result::
        # * Boolean: Are dependencies met before using this plugin?
        def self.valid?
          docker_ok = false
          begin
            ::Docker.validate_version!
            docker_ok = true
          rescue
            log_error "[ #{@node}/#{@environment} ] - Docker is not installed correctly. Please install it. Error: #{$ERROR_INFO}"
          end
          docker_ok
        end

        # Create an instance.
        # Reuse an existing one if it already exists.
        # [API] - This method is mandatory
        def create
          # Get the image name for this node
          image = @nodes_handler.get_image_of(@node).to_sym
          # Find if we have such an image registered
          raise "[ #{@node}/#{@environment} ] - Unknown OS image #{image} defined for node #{@node}" unless @config.known_os_images.include?(image)
          
          # Build the image if it does not exist
          image_tag = "hpc_image_#{image}"
          docker_image = nil
          image_futex_file = "#{Dir.tmpdir}/hpc_docker_image_futexes/#{image_tag}"
          FileUtils.mkdir_p File.dirname(image_futex_file)
          Futex.new(image_futex_file).open do
            docker_image = ::Docker::Image.all.find { |search_image| !search_image.info['RepoTags'].nil? && search_image.info['RepoTags'].include?("#{image_tag}:latest") }
            unless docker_image
              log_debug "[ #{@node}/#{@environment} ] - Creating Docker image #{image_tag}..."
              Excon.defaults[:read_timeout] = 600
              docker_image = ::Docker::Image.build_from_dir(@config.os_image_dir(image))
              docker_image.tag repo: image_tag
            end
          end
          container_name = "hpc_docker_container_#{@node}_#{@environment}"
          container_futex_file = "#{Dir.tmpdir}/hpc_docker_container_futexes/#{image_tag}"
          FileUtils.mkdir_p File.dirname(container_futex_file)
          Futex.new(container_futex_file).open do
            old_docker_container = ::Docker::Container.all(all: true).find { |container| container.info['Names'].include? "/#{container_name}" }
            @container =
              if old_docker_container
                old_docker_container
              else
                log_debug "[ #{@node}/#{@environment} ] - Creating Docker container #{container_name}..."
                # We add the SYS_PTRACE capability as some images need to restart services (for example postfix) and those services need the rights to ls in /proc/{PID}/exe to check if a status is running. Without SYS_PTRACE such ls returns permission denied and the service can't be stopped (as init.d always returns it as stopped even when running).
                # We add the privileges as some containers need to install and configure the udev package, which needs RW access to /sys.
                # We add the bind to cgroup volume to be able to test systemd specifics (enabling/disabling services for example).
                ::Docker::Container.create(
                  name: container_name,
                  image: image_tag,
                  CapAdd: 'SYS_PTRACE',
                  Privileged: true,
                  Binds: ['/sys/fs/cgroup:/sys/fs/cgroup:ro'],
                  # Some playbooks need the hostname to be set to a correct FQDN
                  Hostname: "#{@node}.testdomain"
                )
              end
          end
        end

        # Start an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def start
          log_debug "[ #{@node}/#{@environment} ] - Start Docker Container #{@container.refresh!.info['Name'][1..]} ..."
          @container.start
        end

        # Stop an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def stop
          log_debug "[ #{@node}/#{@environment} ] - Stop Docker Container #{@container.refresh!.info['Name'][1..]} ..."
          @container.stop
        end

        # Destroy an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def destroy
          log_debug "[ #{@node}/#{@environment} ] - Destroy Docker Container #{@container.refresh!.info['Name'][1..]} ..."
          @container.remove
          @container = nil
        end

        # Return the state of an instance
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
              @container.refresh!.info['State']['Status'].to_sym
            rescue
              log_error "[ #{@node}/#{@environment} ] - Error while reading state of Docker container: #{$ERROR_INFO}"
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
          @container.refresh!
          @container.json['NetworkSettings']['IPAddress']
        end

      end

    end

  end

end
