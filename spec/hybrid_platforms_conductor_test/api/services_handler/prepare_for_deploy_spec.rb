describe HybridPlatformsConductor::ServicesHandler do

  context 'when checking preparation for deployment' do

    it 'prepares 1 platform' do
      called = false
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be false
            expect(why_run).to be false
            called = true
          end
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false,
          why_run: false
        )
        expect(called).to be true
      end
    end

    it 'prepares 1 platform with secrets' do
      called = false
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq('my_secret' => 'value')
            expect(local_environment).to be false
            expect(why_run).to be false
            called = true
          end
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1] },
          secrets: { 'my_secret' => 'value' },
          local_environment: false,
          why_run: false
        )
        expect(called).to be true
      end
    end

    it 'prepares 1 platform with local environment' do
      called = false
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be true
            expect(why_run).to be false
            called = true
          end
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: true,
          why_run: false
        )
        expect(called).to be true
      end
    end

    it 'prepares 1 platform in why-run mode' do
      called = false
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1],
          prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
            expect(services).to eq('node1' => %w[service1])
            expect(secrets).to eq({})
            expect(local_environment).to be false
            expect(why_run).to be true
            called = true
          end
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1] },
          secrets: {},
          local_environment: false,
          why_run: true
        )
        expect(called).to be true
      end
    end

    it 'prepares several platforms' do
      called = {
        'platform1' => false,
        'platform2' => false,
        'platform3' => false
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => { services: %w[service1] } },
            deployable_services: %w[service1],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node1' => %w[service1])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform1'] = true
            end
          },
          'platform2' => {
            nodes: { 'node2' => { services: %w[service2] } },
            deployable_services: %w[service2],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node2' => %w[service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform2'] = true
            end
          },
          'platform3' => {
            nodes: { 'node3' => { services: %w[service3] } },
            deployable_services: %w[service3],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node3' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform3'] = true
            end
          }
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1], 'node2' => %w[service2], 'node3' => %w[service3] },
          secrets: {},
          local_environment: false,
          why_run: false
        )
        expect(called).to eq(
          'platform1' => true,
          'platform2' => true,
          'platform3' => true
        )
      end
    end

    it 'prepares only concerned platforms' do
      called = {
        'platform1' => false,
        'platform2' => false,
        'platform3' => false
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => { services: %w[service1] } },
            deployable_services: %w[service1],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node1' => %w[service1])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform1'] = true
            end
          },
          'platform2' => {
            nodes: { 'node2' => { services: %w[service2] } },
            deployable_services: %w[service2],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node2' => %w[service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform2'] = true
            end
          },
          'platform3' => {
            nodes: { 'node3' => { services: %w[service3] } },
            deployable_services: %w[service3],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node1' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform3'] = true
            end
          }
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node1' => %w[service1 service3] },
          secrets: {},
          local_environment: false,
          why_run: false
        )
        expect(called).to eq(
          'platform1' => true,
          'platform2' => false,
          'platform3' => true
        )
      end
    end

    it 'prepares platforms only with services they can deploy' do
      called = {
        'platform1' => false,
        'platform2' => false,
        'platform3' => false
      }
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node' => { services: %w[service1 service2 service3 service4 service5 service6] } },
            deployable_services: %w[service1 service2],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node' => %w[service1 service2])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform1'] = true
            end
          },
          'platform2' => {
            nodes: {},
            deployable_services: %w[service3 service4],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node' => %w[service3])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform2'] = true
            end
          },
          'platform3' => {
            nodes: {},
            deployable_services: %w[service5 service6],
            prepare_for_deploy: proc do |services:, secrets:, local_environment:, why_run:|
              expect(services).to eq('node' => %w[service5 service6])
              expect(secrets).to eq({})
              expect(local_environment).to be false
              expect(why_run).to be false
              called['platform3'] = true
            end
          }
        }
      ) do
        test_services_handler.prepare_for_deploy(
          services: { 'node' => %w[service1 service2 service3 service5 service6] },
          secrets: {},
          local_environment: false,
          why_run: false
        )
        expect(called).to eq(
          'platform1' => true,
          'platform2' => true,
          'platform3' => true
        )
      end
    end

  end

end
