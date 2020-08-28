module HybridPlatformsConductorTest

  module Helpers

    module ProvisionerProxmoxHelpers

      # Setup a test platform for Proxmox tests
      #
      # Parameters::
      # * *node_metadata* (Hash<Symbol,Object>): Extra node metadata [default: {}]
      # * *environment* (String): Environment to be used [default: 'test']
      # * Proc: Code called when everything is setup
      #   * Parameters::
      #     * *instance* (Provisioner): A new Provisioner instance targeting the Proxmox instance
      #     * *repository* (String): The platforms' repository
      def with_test_proxmox_platform(node_metadata: {}, environment: 'test')
        with_repository('platform') do |repository|
          os_image_path = "#{repository}/os_image"
          FileUtils.mkdir_p os_image_path
          FileUtils.cp "#{__dir__}/../api/deployer/provisioners/proxmox/proxmox.json", "#{os_image_path}/proxmox.json"
          with_platforms("
            os_image :test_image, '#{os_image_path}'
            test_platform path: '#{repository}'
            proxmox(
              api_url: 'https://my-proxmox.my-domain.com:8006',
              sync_node: 'node',
              test_config: {
                pve_nodes: ['pve_node_name'],
                vm_ips_list: %w[
                  192.168.0.100
                  192.168.0.101
                ],
                vm_ids_range: [1000, 1100],
                coeff_ram_consumption: 10,
                coeff_disk_consumption: 1,
                expiration_period_secs: 24 * 60 * 60,
                limits: {
                  nbr_vms_max: 5,
                  cpu_loads_thresholds: [10, 10, 10],
                  ram_percent_used_max: 0.75,
                  disk_percent_used_max: 0.75
                }
              },
              vm_config: {
                vm_dns_servers: ['8.8.8.8'],
                vm_search_domain: 'my-domain.com',
                vm_gateway: '192.168.0.1'
              }
            )
          ") do
            register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
            self.test_platforms_info = { 'platform' => {
              nodes: { 'node' => { meta: { host_ip: '192.168.42.42', image: 'test_image' }.merge(node_metadata) } }
            } }
            instance = HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.new(
              'node',
              environment: environment,
              logger: logger,
              logger_stderr: logger,
              cmd_runner: test_cmd_runner,
              nodes_handler: test_nodes_handler,
              actions_executor: test_actions_executor
            )
            yield instance, repository
          end
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox getting info about the existing nodes
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *nodes_info* (Array<Hash>): Nodes info returned by the Proxmox API [default: []]
      # * *extra_expects* (Proc or nil): Code called for additional expectations on the proxmox instance, or nil if none [default: nil]
      #   * Parameters::
      #     * *proxmox* (Double): The mocked Proxmox instance
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_get_nodes_info(proxmox_user: nil, proxmox_password: nil, nodes_info: [], extra_expects: nil)
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox info instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock checking existing nodes
          expect(proxmox).to receive(:get).with('nodes') do
            nodes_info
          end
          extra_expects.call(proxmox) unless extra_expects.nil?
          proxmox
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox creating a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *hostname* (String): Hostname that should be mocked [default: 'node.test.hpc-test.com']
      # * *environment* (String): Environment name that should be mocked [default: 'test']
      # * *cpus* (Integer): Number of CPUs to reserve [default: 2]
      # * *ram_mb* (Integer): RAM MB to reserve [default: 1024]
      # * *disk_gb* (Integer): Disk GB to reserve [default: 10]
      # * *task_status* (String): Proxmox creation task status [default: 'OK']
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_create_node(
        proxmox_user: nil,
        proxmox_password: nil,
        hostname: 'node.test.hpc-test.com',
        environment: 'test',
        cpus: 2,
        ram_mb: 1024,
        disk_gb: 10,
        task_status: 'OK'
      )
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox create instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock creating a new container
          expect(proxmox).to receive(:post).with(
            'nodes/pve_node_name/lxc',
            {
              cores: cpus,
              cpulimit: cpus,
              hostname: hostname,
              memory: ram_mb,
              nameserver: '8.8.8.8',
              net0: 'name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.100/32',
              ostemplate: 'template_storage/os_image.tar.gz',
              password: 'root_pwd',
              rootfs: "local-lvm:#{disk_gb}",
              searchdomain: 'my-domain.com',
              vmid: 1024,
              description: <<~EOS
                ===== HPC info =====
                node: node
                environment: #{environment}
              EOS
            }
          ) do |_path, options|
            @proxmox_create_options = options
            'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:create::root@pam:'
          end
          # Mock checking creation task status
          expect(proxmox).to receive(:task_status).with('UPID:pve_node_name:0000A504:6DEABF24:5F44669B:create::root@pam:') do
            task_status
          end
          proxmox
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox starting a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *task_status* (String): Proxmox start task status [default: 'OK']
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_start_node(
        proxmox_user: nil,
        proxmox_password: nil,
        task_status: 'OK'
      )
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox create instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock start a container
          expect(proxmox).to receive(:post).with('nodes/pve_node_name/lxc/1024/status/start') do
            'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:start::root@pam:'
          end
          # Mock checking creation task status
          expect(proxmox).to receive(:task_status).with('UPID:pve_node_name:0000A504:6DEABF24:5F44669B:start::root@pam:') do
            task_status
          end
          proxmox
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox stopping a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *task_status* (String): Proxmox stop task status [default: 'OK']
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_stop_node(
        proxmox_user: nil,
        proxmox_password: nil,
        task_status: 'OK'
      )
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox create instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock start a container
          expect(proxmox).to receive(:post).with('nodes/pve_node_name/lxc/1024/status/stop') do
            'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:stop::root@pam:'
          end
          # Mock checking creation task status
          expect(proxmox).to receive(:task_status).with('UPID:pve_node_name:0000A504:6DEABF24:5F44669B:stop::root@pam:') do
            task_status
          end
          proxmox
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox destroying a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *task_status* (String): Proxmox destroy task status [default: 'OK']
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_destroy_node(
        proxmox_user: nil,
        proxmox_password: nil,
        task_status: 'OK'
      )
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox create instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock start a container
          expect(proxmox).to receive(:delete).with('nodes/pve_node_name/lxc/1024') do
            'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:destroy::root@pam:'
          end
          # Mock checking creation task status
          expect(proxmox).to receive(:task_status).with('UPID:pve_node_name:0000A504:6DEABF24:5F44669B:destroy::root@pam:') do
            task_status
          end
          proxmox
        end
      end

      # Get a mocking code corresponding to a call to Proxmox.new.
      # This code should mock Proxmox getting the status a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *status* (String): Mocked status [default: 'created']
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_status_node(
        proxmox_user: nil,
        proxmox_password: nil,
        task_status: 'OK'
      )
        proc do |url, pve_node, user, password, realm, options|
          expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
          expect(pve_node).to eq 'my-proxmox'
          expect(user).to eq proxmox_user
          expect(password).to eq proxmox_password
          expect(realm).to eq 'pam'
          expect(options[:verify_ssl]).to eq false
          proxmox = double 'Proxmox create instance'
          # Mock initialization
          expect(proxmox).to receive(:logger=) do
            # Nothing
          end
          expect(proxmox).to receive(:logger_stderr=) do
            # Nothing
          end
          # Mock getting status of a container
          expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc') do
            [
              {
                'vmid' => '1024'
              }
            ]
          end
          expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc/1024/status/current') do
            {
              'status' => 'created'
            }
          end
          proxmox
        end
      end

      # Mock a call to the reserve_proxmox_container sync node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *error* (String or nil): Error to be mocked by reserve_proxmox_container, or nil in case of success [default: nil]
      # * *cpus* (Integer): Number of CPUs to reserve [default: 2]
      # * *ram_mb* (Integer): RAM MB to reserve [default: 1024]
      # * *disk_gb* (Integer): Disk GB to reserve [default: 10]
      def mock_call_to_reserve_proxmox_container(
        proxmox_user: nil,
        proxmox_password: nil,
        error: nil,
        cpus: 2,
        ram_mb: 1024,
        disk_gb: 10
      )
        expect_actions_executor_runs [
          proc do |actions|
            expect(actions.keys).to eq ['node']
            expect(actions['node'].size).to eq 3
            # First action should be to copy the reserve_proxmox_container code
            expect(actions['node'][0].keys).to eq [:scp]
            expect(actions['node'][0][:scp].first[0]).to match /^.+\/hpc_plugins\/provisioner\/proxmox\/$/
            expect(actions['node'][0][:scp].first[1]).to eq '.'
            # Second action should be to copy the ProxmoxWaiter config
            expect(actions['node'][1]).to eq({ scp: { 'config.json' => './proxmox' } })
            # Third action should be to execute reserve_proxmox_container
            expect(actions['node'][2]).to eq({
              remote_bash: {
                commands: "./proxmox/reserve_proxmox_container --cpus #{cpus} --ram-mb #{ram_mb} --disk-gb #{disk_gb}",
                env: {
                  'hpc_user_for_proxmox' => proxmox_user,
                  'hpc_password_for_proxmox' => proxmox_password
                }
              }
            })
            result =
              if error
                { error: error }
              else
                {
                  pve_node: 'pve_node_name',
                  vm_id: 1024,
                  vm_ip: '192.168.0.100'
                }
              end
            { 'node' => [0, <<~EOS, ''] }
              ===== JSON =====
              #{JSON.pretty_generate(result)}
            EOS
          end
        ]
      end

      # Mock a series of Proxmox calls, and expect them to occur.
      #
      # Parameters::
      # * *calls* (Array<Proc>): List of mocked calls
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *error* (String or nil): Error to be mocked by reserve_proxmox_container, or nil in case of success [default: nil]
      # * *cpus* (Integer): Number of CPUs to reserve [default: 2]
      # * *ram_mb* (Integer): RAM MB to reserve [default: 1024]
      # * *disk_gb* (Integer): Disk GB to reserve [default: 10]
      # * *reserve* (Boolean): Do we expect the resource reservation to occur? [default: true]
      def mock_proxmox_calls_with(
        calls,
        proxmox_user: nil,
        proxmox_password: nil,
        error: nil,
        cpus: 2,
        ram_mb: 1024,
        disk_gb: 10,
        reserve: true
      )
        if reserve
          # Mock querying reserve_proxmox_container
          mock_call_to_reserve_proxmox_container(
            proxmox_user: proxmox_user,
            proxmox_password: proxmox_password,
            error: error,
            cpus: cpus,
            ram_mb: ram_mb,
            disk_gb: disk_gb
          )
        end
        expect(::Proxmox::Proxmox).to receive(:new).exactly(calls.size).times do |url, pve_node, user, password, realm, options|
          calls.shift.call(url, pve_node, user, password, realm, options)
        end
      end

      # Mock the Proxmox API calls to map a given Proxmox status.
      # Mock any call to the paths of the API to serve a given nodes information.
      # Mock also calls to stop and destroy containers, and log those actions so that they can be checked by the test case later.
      #
      # Parameters::
      # * *proxmox_user* (String): Proxmox user to be used for the API, or nil if none [default: nil]
      # * *proxmox_password* (String): Proxmox password to be used for the API, or nil if none [default: nil]
      # * *mocked_pve_nodes* (Array< Hash< String, Hash<Symbol,Object> > > or Hash< String, Hash<Symbol,Object> >):
      #   List of (or single) PVE node information, per PVE node name. [default: { 'pve_node_name' => {} }]
      #   If used as a list, it is expected that the Proxmox API be used as many times as the number of items in the list, and the mocked info will follow the list order.
      #   Here are the properties of a PVE node:
      #   * *loadavg* ([Float, Float, Float]): Load average of the node [default: [0.1, 0.2, 0.3]]
      #   * *memory_total* (Integer): Bytes of RAM of this PVE node [default: 16 * 1024 * 1024 * 1024]
      #   * *storage_total* (Integer): Bytes of disk of this PVE node [default: 100 * 1024 * 1024 * 1024]
      #   * *lxc_containers* (Hash<Integer, Hash<Symbol,Object> >): LXC containers info, per VM ID [default: {}]
      #     * *maxdisk* (Integer): Bytes of disk allocated to this VM [default: 1024 * 1024 * 1024]
      #     * *maxmem* (Integer): Bytes of RAM allocated to this VM [default: 1024 * 1024 * 1024]
      #     * *cpus* (Integer): CPUs allocated to this VM [default: 1]
      #     * *ip* (String): IP allocated to this node [default: 192.168.0.<vmid % 254 + 1>]
      #     * *status* (String): Status of this node [default: 'running']
      def mock_proxmox(
        proxmox_user: nil,
        proxmox_password: nil,
        mocked_pve_nodes: { 'pve_node_name' => {} }
      )
        # List of proxmox actions that have been mocked and their corresponding properties
        # Array< [Symbol, Object] >
        @proxmox_actions = []
        mocked_pve_nodes = [mocked_pve_nodes] unless mocked_pve_nodes.is_a?(Array)
        mock_proxmox_calls_with(
          mocked_pve_nodes.map do |pve_nodes|
            # Complete pve_nodes with default values
            pve_nodes = Hash[pve_nodes.map do |pve_node_name, pve_node_info|
              pve_node_info[:lxc_containers] = Hash[(pve_node_info.key?(:lxc_containers) ? pve_node_info[:lxc_containers] : {}).map do |vm_id, vm_info|
                [
                  vm_id,
                  {
                    maxdisk: 1024 * 1024 * 1024,
                    maxmem: 1024 * 1024 * 1024,
                    cpus: 1,
                    ip: "192.168.0.#{(vm_id % 254) + 1}",
                    status: 'running'
                  }.merge(vm_info)
                ]
              end]
              [
                pve_node_name,
                {
                  loadavg: [0.1, 0.2, 0.3],
                  memory_total: 16 * 1024 * 1024 * 1024,
                  storage_total: 100 * 1024 * 1024 * 1024
                }.merge(pve_node_info)
              ]
            end]
            proc do |url, pve_node, user, password, realm, options|
              expect(url).to eq 'https://my-proxmox.my-domain.com:8006/api2/json/'
              expect(pve_node).to eq 'my-proxmox'
              expect(user).to eq proxmox_user
              expect(password).to eq proxmox_password
              expect(realm).to eq 'pam'
              expect(options[:verify_ssl]).to eq false
              proxmox = double 'Proxmox create instance'
              # Mock getting status of a container
              allow(proxmox).to receive(:get) do |path|
                case path
                when 'nodes'
                  pve_nodes.keys.map { |pve_node_name| { 'node' => pve_node_name } }
                when /^nodes\/([^\/]+)\/status$/
                  pve_node_name = $1
                  {
                    'loadavg' => pve_nodes[pve_node_name][:loadavg].map(&:to_s),
                    'memory' => {
                      'total' => pve_nodes[pve_node_name][:memory_total]
                    }
                  }
                when /^nodes\/([^\/]+)\/storage$/
                  pve_node_name = $1
                  [
                    {
                      'storage' => 'local-lvm',
                      'total' => pve_nodes[pve_node_name][:storage_total]
                    }
                  ]
                when /^nodes\/([^\/]+)\/lxc$/
                  pve_node_name = $1
                  pve_nodes[pve_node_name][:lxc_containers].map do |vm_id, vm_info|
                    {
                      'vmid' => vm_id.to_s,
                      'maxdisk' => vm_info[:maxdisk],
                      'maxmem' => vm_info[:maxmem],
                      'cpus' => vm_info[:cpus]
                    }
                  end
                when /^nodes\/([^\/]+)\/lxc\/([^\/]+)\/config$/
                  pve_node_name = $1
                  vmid = $2
                  {
                    'net0' => "ip=#{pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:ip]}/32"
                  }
                when /^nodes\/([^\/]+)\/lxc\/([^\/]+)\/status\/current$/
                  pve_node_name = $1
                  vmid = $2
                  {
                    'status' => pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:status]
                  }
                else
                  raise "Unknown Proxmox API get call: #{path}. Please adapt the test framework."
                end
              end
              # Mock some post actions
              allow(proxmox).to receive(:post) do |path|
                @proxmox_actions << [:post, path]
                case path
                when /^nodes\/([^\/]+)\/lxc\/([^\/]+)\/status\/stop$/
                  pve_node_name = $1
                  vmid = $2
                  "UPID:#{pve_node_name}:0000A504:6DEABF24:5F44669B:stop_#{vmid}::root@pam:"
                else
                  raise "Unknown Proxmox API post call: #{path}. Please adapt the test framework."
                end
              end
              # Mock some delete actions
              allow(proxmox).to receive(:delete) do |path|
                @proxmox_actions << [:delete, path]
                case path
                when /^nodes\/([^\/]+)\/lxc\/([^\/]+)$/
                  pve_node_name = $1
                  vmid = $2
                  # Make sure we delete the mocked information as well
                  pve_nodes[pve_node_name][:lxc_containers].delete(Integer(vmid))
                  "UPID:#{pve_node_name}:0000A504:6DEABF24:5F44669B:destroy_#{vmid}::root@pam:"
                else
                  raise "Unknown Proxmox API post call: #{path}. Please adapt the test framework."
                end
              end
              # Mock tasks completion
              allow(proxmox).to receive(:task_status) do |task_name|
                'OK'
              end
              proxmox
            end
          end,
          reserve: false
        )
      end

      # Prepare a repository to test reserve_proxmox_container
      #
      # Parameters::
      # * Proc: Code to be called with repository setup
      def with_sync_node
        with_repository('sync_node') do |repository|
          @repository = repository
          yield
        end
      end

      # Call the reserve_proxmox_container script and get its result as JSON.
      # Prerequisite: This is called within a with_sync_node session.
      #
      # Parameters::
      # * *cpus* (Integer): Required CPUs
      # * *ram_mb* (Integer): Required RAM MB
      # * *disk_gb* (Integer): Required Disk GB
      # * *config* (Hash): Configuration overriding defaults to store in the config file [default: {}]
      # * *max_retries* (Integer): Specify the max number of retries [default: 1]
      # * *allocations* (Hash): Content of the allocations db file [default: {}]
      # Result::
      # * Hash: JSON result of the call
      def call_reserve_proxmox_container(cpus, ram_mb, disk_gb, config: {}, max_retries: 1, allocations: {})
        # Make sure we set default values in the config
        config = {
          proxmox_api_url: 'https://my-proxmox.my-domain.com:8006',
          allocations_file: "#{@repository}/proxmox/allocations.json",
          pve_nodes: ['pve_node_name'],
          vm_ips_list: %w[
            192.168.0.100
            192.168.0.101
            192.168.0.102
          ],
          vm_ids_range: [1000, 1100],
          coeff_ram_consumption: 10,
          coeff_disk_consumption: 1,
          expiration_period_secs: 24 * 60 * 60,
          limits: {
            nbr_vms_max: 5,
            cpu_loads_thresholds: [10, 10, 10],
            ram_percent_used_max: 0.75,
            disk_percent_used_max: 0.75
          }
        }.merge(config)
        FileUtils.cp_r "#{__dir__}/../../../lib/hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox", @repository
        File.write("#{@repository}/proxmox/config.json", config.to_json)
        File.write("#{@repository}/proxmox/allocations.json", allocations.to_json)
        # Call the script by loading the Ruby file mocking the ARGV and ENV variables
        old_argv = ARGV.dup
        old_stdout = $stdout
        ARGV.replace([
          '--cpus', cpus.to_s,
          '--ram-mb', ram_mb.to_s,
          '--disk-gb', disk_gb.to_s,
          '--max-retries', max_retries.to_s,
          '--wait-before-retry', '0'
        ])
        $stdout = StringIO.new unless logger.debug?
        begin
          load "#{@repository}/proxmox/reserve_proxmox_container"
          if logger.debug?
            raise 'This test can\'t run in debug mode.'
          else
            @stdout = $stdout.string
          end
        ensure
          ARGV.replace old_argv
          $stdout = old_stdout
        end
        stdout_lines = @stdout.split("\n")
        JSON.parse(stdout_lines[stdout_lines.index('===== JSON =====') + 1..-1].join("\n")).transform_keys(&:to_sym)
      end

    end

  end

end
