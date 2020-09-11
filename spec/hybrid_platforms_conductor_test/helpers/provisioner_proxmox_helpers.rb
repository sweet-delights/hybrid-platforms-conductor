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
      # This code should mock Proxmox starting a node
      #
      # Parameters::
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *task_name* (String): Proxmox start task name [default: 'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:start::root@pam:']
      # * *task_status* (String or nil): Proxmox start task status, or nil if no task status query is to be expected [default: 'OK']
      # * *nbr_api_errors* (Integer): Number of API errors 500 to mock before getting a successful query [defaults: 0]
      # Result::
      # * Proc: Code called in place of Proxmox.new. Signature is the same as Proxmox.new.
      def mock_proxmox_to_start_node(
        proxmox_user: nil,
        proxmox_password: nil,
        task_name: 'UPID:pve_node_name:0000A504:6DEABF24:5F44669B:start::root@pam:',
        task_status: 'OK',
        nbr_api_errors: 0
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
          idx_try = 0
          expect(proxmox).to receive(:post).exactly(nbr_api_errors + (task_status.nil? ? 0 : 1)).times.with('nodes/pve_node_name/lxc/1024/status/start') do
            idx_try += 1
            idx_try <= nbr_api_errors ? 'NOK: error code = 500' : task_name
          end
          # Mock checking task status
          unless task_status.nil?
            # Mock checking task status
            expect(proxmox).to receive(:get).with("nodes/pve_node_name/tasks/#{task_name}/status") do
              { 'status' => task_status }
            end
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
          # Mock checking task status
          expect(proxmox).to receive(:get).with('nodes/pve_node_name/tasks/UPID:pve_node_name:0000A504:6DEABF24:5F44669B:stop::root@pam:/status') do
            { 'status' => task_status }
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
          # Mock checking task status
          expect(proxmox).to receive(:get).with('nodes/pve_node_name/tasks/UPID:pve_node_name:0000A504:6DEABF24:5F44669B:destroy::root@pam:/status') do
            { 'status' => task_status }
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
      # * *error_on_create* (String or nil): Error to be mocked by reserve_proxmox_container create, or nil in case of success [default: nil]
      # * *error_on_destroy* (String or nil): Error to be mocked by reserve_proxmox_container destroy, or nil in case of success [default: nil]
      # * *release_vm_id* (Integer or nil): VM ID expected to be released, or nil if none [default: nil]
      def mock_call_to_reserve_proxmox_container(
        proxmox_user: nil,
        proxmox_password: nil,
        error_on_create: nil,
        error_on_destroy: nil,
        release_vm_id: nil
      )
        runs = [
          proc do |actions|
            expect(actions.keys).to eq ['node']
            expect(actions['node'].size).to eq 4
            # First action should be to copy the reserve_proxmox_container code
            expect(actions['node'][0].keys).to eq [:scp]
            expect(actions['node'][0][:scp].first[0]).to match /^.+\/hpc_plugins\/provisioner\/proxmox\/$/
            expect(actions['node'][0][:scp].first[1]).to eq '.'
            # Second action should be to copy the ProxmoxWaiter config
            expect(actions['node'][1]).to eq({ scp: { 'config.json' => './proxmox' } })
            # Third action should be to copy the VM info JSON file
            expect(actions['node'][2].keys).to eq [:scp]
            expect(actions['node'][2][:scp].first[0]).to match /^.+\/create_vm_.+\.json$/
            @proxmox_create_options = JSON.parse(File.read(actions['node'][2][:scp].first[0]))
            expect(actions['node'][2][:scp].first[1]).to eq './proxmox'
            # Forth action should be to execute reserve_proxmox_container
            expect(actions['node'][3].keys).to eq [:remote_bash]
            expect(actions['node'][3][:remote_bash][:commands]).to match /^.\/proxmox\/reserve_proxmox_container --create .+\/create_vm_.+\.json$/
            expect(actions['node'][3][:remote_bash][:env]).to eq({
              'hpc_user_for_proxmox' => proxmox_user,
              'hpc_password_for_proxmox' => proxmox_password
            })
            result =
              if error_on_create
                { error: error_on_create }
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
        if release_vm_id
          runs << proc do |actions|
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
                commands: "./proxmox/reserve_proxmox_container --destroy #{release_vm_id}",
                env: {
                  'hpc_user_for_proxmox' => proxmox_user,
                  'hpc_password_for_proxmox' => proxmox_password
                }
              }
            })
            result =
              if error_on_destroy
                { error: error_on_destroy }
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
        end
        expect_actions_executor_runs runs
      end

      # Mock a series of Proxmox calls, and expect them to occur.
      #
      # Parameters::
      # * *calls* (Array<Proc>): List of mocked calls
      # * *proxmox_user* (String or nil): Proxmox user used to connect to Proxmox API [default: nil]
      # * *proxmox_password* (String or nil): Proxmox password used to connect to Proxmox API [default: nil]
      # * *error_on_create* (String or nil): Error to be mocked by reserve_proxmox_container create, or nil in case of success [default: nil]
      # * *error_on_destroy* (String or nil): Error to be mocked by reserve_proxmox_container destroy, or nil in case of success [default: nil]
      # * *reserve* (Boolean): Do we expect the resource reservation to occur? [default: true]
      # * *release_vm_id* (Integer or nil): VM ID expected to be released, or nil if none [default: nil]
      def mock_proxmox_calls_with(
        calls,
        proxmox_user: nil,
        proxmox_password: nil,
        error_on_create: nil,
        error_on_destroy: nil,
        reserve: true,
        release_vm_id: nil
      )
        if reserve || release_vm_id
          # Mock querying reserve_proxmox_container
          mock_call_to_reserve_proxmox_container(
            proxmox_user: proxmox_user,
            proxmox_password: proxmox_password,
            error_on_create: error_on_create,
            error_on_destroy: error_on_destroy,
            release_vm_id: release_vm_id
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
      #     * *debug* (Boolean): Do we mark the VM as debug? [default: false]
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
                    status: 'running',
                    creation_date: (Time.now - 60).utc,
                    debug: false
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
                    'net0' => "ip=#{pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:ip]}/32",
                    'description' => <<~EOS
                      ===== HPC Info =====
                      node: test_node
                      environment: test_env
                      debug: #{pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:debug] ? 'true' : 'false'}
                      creation_date: #{pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:creation_date].strftime('%FT%T')}
                    EOS
                  }
                when /^nodes\/([^\/]+)\/lxc\/([^\/]+)\/status\/current$/
                  pve_node_name = $1
                  vmid = $2
                  {
                    'status' => pve_nodes[pve_node_name][:lxc_containers][Integer(vmid)][:status]
                  }
                when /^nodes\/([^\/]+)\/tasks\/([^\/]+)\/status$/
                  pve_node_name = $1
                  task = $2
                  # Mock tasks completion
                  {
                    'status' => 'OK'
                  }
                else
                  raise "Unknown Proxmox API get call: #{path}. Please adapt the test framework."
                end
              end
              # Mock some post actions
              allow(proxmox).to receive(:post) do |path, args|
                @proxmox_actions << [:post, path, args].compact
                case path
                when /^nodes\/([^\/]+)\/lxc$/
                  pve_node_name = $1
                  "UPID:#{pve_node_name}:0000A504:6DEABF24:5F44669B:create::root@pam:"
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

      # Call the reserve_proxmox_container script using a given ARGV.
      # Prerequisite: This is called within a with_sync_node session.
      #
      # Parameters::
      # * *argv* (Array<String>): ARGV to give the command
      # * *config* (Hash): Configuration overriding defaults to store in the config file [default: {}]
      # * *max_retries* (Integer): Specify the max number of retries [default: 1]
      # * *wait_before_retry* (Integer): Specify the number of seconds to wait before retry [default: 0]
      # * *create* (Hash or nil): Create file content, or nil if none [default: nil]
      # Result::
      # * Hash: JSON result of the call
      def call_reserve_proxmox_container_with(argv, config: {}, max_retries: 1, wait_before_retry: 0, create: nil)
        # Make sure we set default values in the config
        config = {
          proxmox_api_url: 'https://my-proxmox.my-domain.com:8006',
          futex_file: "#{@repository}/proxmox/allocations.futex",
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
          expire_stopped_vm_timeout_secs: 3,
          limits: {
            nbr_vms_max: 5,
            cpu_loads_thresholds: [10, 10, 10],
            ram_percent_used_max: 0.75,
            disk_percent_used_max: 0.75
          }
        }.merge(config)
        FileUtils.cp_r "#{__dir__}/../../../lib/hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox", @repository
        File.write("#{@repository}/proxmox/config.json", config.to_json)
        script_args = argv + [
          '--max-retries', max_retries.to_s,
          '--wait-before-retry', wait_before_retry.to_s
        ]
        unless create.nil?
          create_file = "#{@repository}/proxmox/create_vm.json"
          File.write(create_file, create.to_json)
          script_args.concat(['--create', create_file])
        end
        # Call the script by loading the Ruby file mocking the ARGV and ENV variables
        old_argv = ARGV.dup
        old_stdout = $stdout
        ARGV.replace(script_args)
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

      # Call the reserve_proxmox_container script and get its result as JSON.
      # Prerequisite: This is called within a with_sync_node session.
      #
      # Parameters::
      # * *cpus* (Integer): Required CPUs
      # * *ram_mb* (Integer): Required RAM MB
      # * *disk_gb* (Integer): Required Disk GB
      # * *config* (Hash): Configuration overriding defaults to store in the config file [default: {}]
      # * *max_retries* (Integer): Specify the max number of retries [default: 1]
      # * *wait_before_retry* (Integer): Specify the number of seconds to wait before retry [default: 0]
      # Result::
      # * Hash: JSON result of the call
      def call_reserve_proxmox_container(cpus, ram_mb, disk_gb, config: {}, max_retries: 1, wait_before_retry: 0)
        call_reserve_proxmox_container_with(
          [],
          config: config,
          max_retries: max_retries,
          wait_before_retry: wait_before_retry,
          create: {
            ostemplate: 'test_template.iso',
            hostname: 'test.hostname.my-domain.com',
            description: "===== HPC Info =====\nnode: test_node\nenvironment: test_env\n",
            cores: cpus,
            cpulimit: cpus,
            memory: ram_mb,
            rootfs: "local-lvm:#{disk_gb}",
            net0: 'name=eth0,bridge=vmbr0,gw=172.16.16.16'
          }
        )
      end

      # Call the reserve_proxmox_container script to release a VM and get its result as JSON.
      # Prerequisite: This is called within a with_sync_node session.
      #
      # Parameters::
      # * *vm_id* (Integer): VM ID to release
      # * *config* (Hash): Configuration overriding defaults to store in the config file [default: {}]
      # * *max_retries* (Integer): Specify the max number of retries [default: 1]
      # Result::
      # * Hash: JSON result of the call
      def call_release_proxmox_container(vm_id, config: {}, max_retries: 1)
        call_reserve_proxmox_container_with(
          [
            '--destroy', vm_id.to_s
          ],
          config: config,
          max_retries: max_retries
        )
      end

      # Expect a list of Proxmox API calls to match a given list.
      # Handle Regexp in the expectation.
      #
      # Parameters::
      # * *expected_proxmox_actions* (Array<Array>): Expected Proxmox actions
      def expect_proxmox_actions_to_be(expected_proxmox_actions)
        expect(@proxmox_actions.size).to eq expected_proxmox_actions.size
        @proxmox_actions.zip(expected_proxmox_actions).each do |proxmox_action, expected_proxmox_action|
          expect(proxmox_action.size).to eq expected_proxmox_action.size
          expect(proxmox_action[0..1]).to eq expected_proxmox_action[0..1]
          if proxmox_action.size >= 3
            # The third argument is a Hash that might have Regexp in the expectation
            expect(proxmox_action[2].keys.sort).to eq expected_proxmox_action[2].keys.sort
            proxmox_action[2].each do |property, value|
              expected_value = expected_proxmox_action[2][property]
              if expected_value.is_a?(Regexp)
                expect(value).to match expected_value
              else
                expect(value).to eq expected_value
              end
            end
          end
        end
      end

    end

  end

end
