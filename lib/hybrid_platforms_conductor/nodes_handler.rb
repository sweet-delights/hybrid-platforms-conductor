require 'json'
require 'ipaddress'
require 'hybrid_platforms_conductor/platforms_dsl'

module HybridPlatformsConductor

  # Provide utilities to handle Nodes configuration
  class NodesHandler

    include PlatformsDsl

    # Activate debug mode? [default: false]
    #   Boolean
    attr_accessor :debug

    # Constructor
    #
    # Parameters::
    # * *debug* (Boolean): Activate debug mode? [default: false]
    def initialize(debug: false)
      @debug = debug
      initialize_platforms_dsl
    end

    # Get the list of known IPs (private and public), and return each associated hostname
    #
    # Result::
    # * Hash<String,String>: List of hostnames per IP address
    def known_ips
      # Keep a cache of it
      unless defined?(@known_ips)
        @known_ips = {}
        # Fill info from the site_meta
        known_hostnames.each do |hostname|
          site_meta = site_meta_for(hostname)
          ['private_ips', 'public_ips'].each do |ip_type|
            if site_meta.key?(ip_type)
              site_meta[ip_type].each do |ip|
                raise "Conflict: #{ip} is already associated to #{@known_ips[ip]}. Cannot associate it to #{hostname}." if @known_ips.key?(ip)
                @known_ips[ip] = hostname
              end
            end
          end
        end
      end
      @known_ips
    end

    # Get the list of host names (resolved) belonging to a hosts list
    #
    # Parameters::
    # * *hosts_list_name* (String): Name of the hosts list
    # * *ignore_unknowns* (Boolean): Do we ignore unknown host names? [default = false]
    # Result::
    # * Array<String>: List of host names
    def host_names_from_list(hosts_list_name, ignore_unknowns: false)
      resolve_hosts(platform_for_list(hosts_list_name).hosts_desc_from_list(hosts_list_name), ignore_unknowns: ignore_unknowns)
    end

    # Read the configuration of a given hostname
    #
    # Parameters::
    # * *hostname* (String): Hostname to read configuration from
    # Result::
    # * Hash<String,Object>: The corresponding JSON configuration
    def node_conf_for(hostname)
      platform_for(hostname).node_conf_for(hostname)
    end

    # Read the site meta of a given hostname
    #
    # Parameters::
    # * *hostname* (String): Hostname to read configuration from
    # Result::
    # * Hash<String,Object> or nil: The corresponding JSON site_meta configuration, or nil if none
    def site_meta_for(hostname)
      json_conf = node_conf_for hostname
      if json_conf.key?('site_meta')
        json_conf['site_meta']
      else
        log_debug "[#{hostname}] - No site_meta key found"
        nil
      end
    end

    # Return the private IP for a given hostname
    #
    # Parameters::
    # * *hostname* (String): Hostname to read configuration from
    # Result::
    # * String or nil: The corresponding private IP, or nil if none
    def private_ip_for(hostname)
      ip = nil
      site_meta_conf = site_meta_for(hostname)
      unless site_meta_conf.nil?
        if site_meta_conf.key?('private_ips')
          ip = site_meta_conf['private_ips'].first
        else
          log_debug "[#{hostname}] - No private IPs defined"
        end
      end
      ip
    end

    # Return the hostname of a given private IP
    #
    # Parameters::
    # * *ip* (String): Private IP
    # Result::
    # * String or nil: The corresponding hostname, or nil if none
    def hostname_for_ip(ip)
      known_hostnames.find do |hostname|
        site_meta_conf = site_meta_for(hostname)
        !site_meta_conf.nil? &&  site_meta_conf.key?('private_ips') && site_meta_conf['private_ips'].include?(ip)
      end
    end

    # Get the IP environment
    #
    # Parameters::
    # * *ip* (String): IP to know location
    # Result::
    # * Symbol: The environment. Can be one of the following:
    #   * :production: Belongs to the Production environment.
    #   * :test: Belongs to the Test environment.
    #   * :all: No information on the environment.
    #   * :unknown: Unknown IP. Should not exist in our networks.
    #   * :outside: IP outside of our networks.
    def ip_env(ip)
      ip1, ip2, ip3, _ip4 = ip.split('.').map(&:to_i)
      case ip1
      when 172
        case ip2
        when 16
          case ip3
          when 0,
            :production
          when 16
            :test
          else
            :all
          end
        else
          :unknown
        end
      else
        :outside
      end
    end

    # Resolve a list of host descriptions into a real list of known host names.
    # A host description can be:
    # * a String, being already a host name,
    # * a Hash, that can contain the following keys:
    #   * *list* (String): Specify the name of a hosts list.
    #   * *platform* (String): The platform name containing the hosts list.
    #   * *all* (Boolean): If true, specify that we want all host names known.
    #
    # Parameters::
    # * *host_descriptions* (Array<Object>): List of host descriptions (can be a single element).
    # * *ignore_unknowns* (Boolean): Do we ignore unknown host names? [default = false]
    # Result::
    # * Array<String>: List of host names
    def resolve_hosts(*host_descriptions, ignore_unknowns: false)
      host_descriptions = host_descriptions.flatten
      # 1. Check for the presence of all
      return known_hostnames if host_descriptions.any? { |host_desc| host_desc.is_a?(Hash) && host_desc.key?(:all) && host_desc[:all] }
      # 2. Expand the hosts lists and platform contents
      string_hosts = []
      host_descriptions.each do |host_desc|
        if host_desc.is_a?(String)
          string_hosts << host_desc
        else
          string_hosts.concat(platform_for_list(host_desc[:list]).hosts_desc_from_list(host_desc[:list])) if host_desc.key?(:list)
          string_hosts.concat(@platforms[host_desc[:platform]].known_hostnames) if host_desc.key?(:platform)
        end
      end
      # 3. Expand the Regexps
      real_hosts = []
      string_hosts.each do |hostname|
        if hostname =~ /^\/(.+)\/$/
          hostname_regexp = Regexp.new($1)
          real_hosts.concat(known_hostnames.select { |known_hostname| known_hostname[hostname_regexp] })
        else
          real_hosts << hostname
        end
      end
      # 4. Sort them unique
      real_hosts.uniq!
      real_hosts.sort!
      # Some sanity checks
      raise 'No host specified' if real_hosts.empty?
      unless ignore_unknowns
        unknown_hostnames = real_hosts - known_hostnames
        raise "Unknown host names: #{unknown_hostnames.join(', ')}" unless unknown_hostnames.empty?
      end
      real_hosts
    end

    # Return host names environments.
    #
    # Parameters::
    # * *host_descriptions* (Array<Object>): List of host descriptions (see resolve_hosts for the details of a host description).
    # Result::
    # * Hash<String,Symbol>: List of environment per real host name (see NodesHandler#ip_environment to know possible environment values).
    def hosts_envs(host_descriptions)
      Hash[resolve_hosts(host_descriptions).map do |hostname|
        private_ip = private_ip_for hostname
        raise "Host #{hostname} has no private IP." if private_ip.nil?
        [
          hostname,
          ip_env(private_ip)
        ]
      end]
    end

    # Get the Artefact repository to be used for a given location
    #
    # Parameters::
    # * *location* (Symbol): The location
    # Result::
    # * String: The artefact repository IP or host
    def artefact_for(location)
      case location
      when :dmz
        '172.16.0.46'
      when :data
        '172.16.1.104'
      when :nce
        '172.16.110.42'
      when :adp
        '172.16.110.42'
      else
        raise "No artefact repository for location: #{location}."
      end
    end

    # Get the list of known IP addresses matching a given IP mask
    #
    # Parameters::
    # * *ip_def* (String): The ip definition (without mask).
    # * *ip_mask* (Integer): The IP mask in bits.
    # Result::
    # * Array<String>: The list of IP addresses matching this mask
    def ips_matching_mask(ip_def, ip_mask)
      # Keep a cache of it
      # Hash<String, Hash<Integer, Array<String> > >
      # Hash<ip_def,      ip_mask,       ip
      @ips_mask = {} unless defined?(@ips_mask)
      @ips_mask[ip_def] = {} unless @ips_mask.key?(ip_def)
      unless @ips_mask[ip_def].key?(ip_mask)
        # For performance, keep a cache of all the IPAddress::IPv4 objects
        @ip_v4_cache = Hash[known_ips.keys.map { |ip, _hostname| [ip, IPAddress::IPv4.new(ip)] }] unless defined?(@ip_v4_cache)
        ip_range = IPAddress::IPv4.new("#{ip_def}/#{ip_mask}")
        @ips_mask[ip_def][ip_mask] = @ip_v4_cache.select { |_ip, ip_v4| ip_range.include?(ip_v4) }.keys
      end
      @ips_mask[ip_def][ip_mask]
    end

    # Get the list of 24 bits IP addresses matching a given IP mask
    #
    # Parameters::
    # * *ip_def* (String): The ip definition (without mask).
    # * *ip_mask* (Integer): The IP mask in bits.
    # Result::
    # * Array<String>: The list of 24 bits IP addresses matching this mask
    def ips_24_matching_mask(ip_def, ip_mask)
      # Keep a cache of it
      # Hash<String, Hash<Integer, Array<String> > >
      # Hash<ip_def,      ip_mask,       ip_24
      @ips_24_mask = {} unless defined?(@ips_24_mask)
      @ips_24_mask[ip_def] = {} unless @ips_24_mask.key?(ip_def)
      unless @ips_24_mask[ip_def].key?(ip_mask)
        ip_range = IPAddress::IPv4.new("#{ip_def}/#{ip_mask}")
        @ips_24_mask[ip_def][ip_mask] = []
        (0..255).each do |ip_third|
          ip_24 = "172.16.#{ip_third}.0/24"
          @ips_24_mask[ip_def][ip_mask] << ip_24 if ip_range.include?(IPAddress::IPv4.new(ip_24))
        end
      end
      @ips_24_mask[ip_def][ip_mask]
    end

    # Complete an option parser with options meant to control this Nodes Handler
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'Nodes handler options:'
      options_parser.on('-o', '--show-hosts', 'Display the list of possible hosts and exit') do
        puts "* Known platforms:\n#{platforms.map { |platform_handler| "* #{platform_handler.platform_type}: #{platform_handler.repository_path}" }.sort.join("\n")}"
        puts
        puts "* Known hosts lists:\n#{known_hosts_lists.sort.join("\n")}"
        puts
        puts "* Known hosts:\n#{known_hostnames.sort.join("\n")}"
        puts
        puts "* Known hosts with description and private IP:\n#{known_hostnames.map do |hostname|
            conf = site_meta_for(hostname)
            "#{platform_for(hostname).repository_path} - #{hostname} (#{private_ip_for(hostname)}) - #{conf.nil? || !conf.key?('description') ? '' : conf['description']}"
          end.sort.join("\n")}"
        puts
        exit 0
      end
    end

    # Complete an option parser with ways to give host names in parameters
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *hosts* (Array): The list of hosts that will be populated by parsing the options
    def options_parse_hosts(options_parser, hosts)
      options_parser.separator ''
      options_parser.separator 'Nodes selection options:'
      options_parser.on('-a', '--all-hosts', 'Select all hosts') do
        hosts << { all: true }
      end
      options_parser.on('-b', '--hosts-platform PLATFORM_NAME', "Select hosts belonging to a given platform name. Available platforms are: #{@platforms.keys.sort.join(', ')} (can be used several times)") do |platform_name|
        hosts << { platform: platform_name }
      end
      options_parser.on('-l', '--hosts-list LIST_NAME', 'Select hosts defined in a hosts list (can be used several times)') do |host_list_name|
        hosts << { list: host_list_name }
      end
      options_parser.on('-n', '--host-name HOST_NAME', 'Select a specific host. Can be a regular expression if used with enclosing "/" characters. (can be used several times)') do |host_name|
        hosts << host_name
      end
    end

    private

    # Log a message if debug is on
    #
    # Parameters::
    # * *msg* (String): Message to give
    def log_debug(msg)
      puts msg if @debug
    end

  end

end
