describe HybridPlatformsConductor::ServicesHandler do

  context 'when checking packaging' do

    it 'packages 1 platform' do
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be false
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false
        )
      end
    end

    it 'packages 1 platform only once' do
      nbr_calls = 0
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be false
            nbr_calls += 1
          end
        }
      ) do
        3.times do
          test_services_handler.package(
            services: { 'node1' => %w[service1] },
            secrets: {},
            local_environment: false
          )
        end
        expect(nbr_calls).to eq 1
      end
    end

    it 'packages 1 platform only once even across different ServicesHandler instances' do
      nbr_calls = 0
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be false
            nbr_calls += 1
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false
        )
        described_class.new(
          logger: logger,
          logger_stderr: logger,
          config: test_config,
          cmd_runner: test_cmd_runner,
          platforms_handler: test_platforms_handler,
          nodes_handler: test_nodes_handler,
          actions_executor: test_actions_executor
        ).package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq 1
      end
    end

    it 'packages 1 platform with secrets' do
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq('my_secret' => 'value')
            expect(local_environment).to be false
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: { 'my_secret' => 'value' },
          local_environment: false
        )
      end
    end

    it 'packages 1 platform for a local environment' do
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be true
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: true
        )
      end
    end

    it 'packages several platforms' do
      nbr_calls = {
        'platform1' => 0,
        'platform2' => 0,
        'platform3' => 0
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => { services: %w[service1] } },
            deployable_services: %w[service1],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node1' => %w[service1])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform1'] += 1
            end
          },
          'platform2' => {
            nodes: { 'node2' => { services: %w[service2] } },
            deployable_services: %w[service2],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node2' => %w[service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform2'] += 1
            end
          },
          'platform3' => {
            nodes: { 'node3' => { services: %w[service3] } },
            deployable_services: %w[service3],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node3' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform3'] += 1
            end
          }
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1], 'node2' => %w[service2], 'node3' => %w[service3] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq(
          'platform1' => 1,
          'platform2' => 1,
          'platform3' => 1
        )
      end
    end

    it 'packages only the concerned platforms' do
      nbr_calls = {
        'platform1' => 0,
        'platform2' => 0,
        'platform3' => 0
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => { services: %w[service1] } },
            deployable_services: %w[service1],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node1' => %w[service1])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform1'] += 1
            end
          },
          'platform2' => {
            nodes: { 'node2' => { services: %w[service2] } },
            deployable_services: %w[service2],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node2' => %w[service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform2'] += 1
            end
          },
          'platform3' => {
            nodes: { 'node3' => { services: %w[service3] } },
            deployable_services: %w[service3],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node1' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform3'] += 1
            end
          }
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1 service3] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq(
          'platform1' => 1,
          'platform2' => 0,
          'platform3' => 1
        )
      end
    end

    it 'packages the platforms with only the services they can deploy' do
      nbr_calls = {
        'platform1' => 0,
        'platform2' => 0,
        'platform3' => 0
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node' => { services: %w[service1 service2 service3 service4 service5 service6] } },
            deployable_services: %w[service1 service2],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node' => %w[service1 service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform1'] += 1
            end
          },
          'platform2' => {
            nodes: {},
            deployable_services: %w[service3 service4],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform2'] += 1
            end
          },
          'platform3' => {
            nodes: {},
            deployable_services: %w[service5 service6],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node' => %w[service5 service6])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform3'] += 1
            end
          }
        }
      ) do
        test_services_handler.package(
          services: { 'node' => %w[service1 service2 service3 service5 service6] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq(
          'platform1' => 1,
          'platform2' => 1,
          'platform3' => 1
        )
      end
    end

    it 'packages only the platforms that were not previously packaged' do
      nbr_calls = {
        'platform1' => 0,
        'platform2' => 0,
        'platform3' => 0
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => { services: %w[service1] } },
            deployable_services: %w[service1],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node1' => %w[service1])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform1'] += 1
            end
          },
          'platform2' => {
            nodes: { 'node2' => { services: %w[service2] } },
            deployable_services: %w[service2],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node2' => %w[service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform2'] += 1
            end
          },
          'platform3' => {
            nodes: { 'node3' => { services: %w[service3] } },
            deployable_services: %w[service3],
            package: proc do |services:, secrets:, local_environment:|
              expect(services).to eq('node3' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              nbr_calls['platform3'] += 1
            end
          }
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1], 'node3' => %w[service3] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq(
          'platform1' => 1,
          'platform2' => 0,
          'platform3' => 1
        )
        test_services_handler.package(
          services: { 'node1' => %w[service1], 'node2' => %w[service2] },
          secrets: {},
          local_environment: false
        )
        expect(nbr_calls).to eq(
          'platform1' => 1,
          'platform2' => 1,
          'platform3' => 1
        )
      end
    end

    it 'packages the platforms again if secrets are different' do
      nbr_calls = 0
      expected_secrets = {}
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] } },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq(expected_secrets)
            expect(local_environment).to be false
            nbr_calls += 1
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false
        )
        expected_secrets = { 'my_secret' => 'value' }
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: { 'my_secret' => 'value' },
          local_environment: false
        )
        expect(nbr_calls).to eq 2
      end
    end

    it 'packages the platforms again if local environment is different' do
      nbr_calls = 0
      expected_local = false
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] } },
          deployable_services: %w[service1],
          package: proc do |services:, secrets:, local_environment:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to eq expected_local
            nbr_calls += 1
          end
        }
      ) do
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false
        )
        expected_local = true
        test_services_handler.package(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: true
        )
        expect(nbr_calls).to eq 2
      end
    end

  end

end
