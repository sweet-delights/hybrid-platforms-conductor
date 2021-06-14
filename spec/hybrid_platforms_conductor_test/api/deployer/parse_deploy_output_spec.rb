describe HybridPlatformsConductor::Deployer do

  context 'when checking parsing output of deployments' do

    it 'returns tasks of deployment logs' do
      with_test_platform do
        expect(test_services_handler).to receive(:parse_deploy_output).with('stdout', 'stderr') do
          [
            {
              node: 'node',
              service: 'service',
              check: false,
              tasks: [
                {
                  name: 'Task1',
                  status: :identical
                },
                {
                  name: 'Task2',
                  status: :changed,
                  diffs: 'Diffs for Task2'
                }
              ]
            }
          ]
        end
        expect(test_deployer.parse_deploy_output('node', 'stdout', 'stderr')).to eq [
          {
            name: 'Task1',
            status: :identical
          },
          {
            name: 'Task2',
            status: :changed,
            diffs: 'Diffs for Task2'
          }
        ]
      end
    end

    it 'returns tasks of deployment logs from several services deployments' do
      with_test_platform do
        expect(test_services_handler).to receive(:parse_deploy_output).with('stdout', 'stderr') do
          [
            {
              node: 'node1',
              service: 'service1',
              check: false,
              tasks: [
                {
                  name: 'Task1',
                  status: :identical
                },
                {
                  name: 'Task2',
                  status: :changed,
                  diffs: 'Diffs for Task2'
                }
              ]
            },
            {
              node: 'node2',
              service: 'service2',
              check: false,
              tasks: [
                {
                  name: 'Task3',
                  status: :identical
                },
                {
                  name: 'Task4',
                  status: :changed,
                  diffs: 'Diffs for Task4'
                }
              ]
            }
          ]
        end
        expect(test_deployer.parse_deploy_output('node', 'stdout', 'stderr')).to eq [
          {
            name: 'Task1',
            status: :identical
          },
          {
            name: 'Task2',
            status: :changed,
            diffs: 'Diffs for Task2'
          },
          {
            name: 'Task3',
            status: :identical
          },
          {
            name: 'Task4',
            status: :changed,
            diffs: 'Diffs for Task4'
          }
        ]
      end
    end

  end

end
