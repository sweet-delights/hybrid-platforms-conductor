describe HybridPlatformsConductor::ServicesHandler do

  context 'checking parsing deployment outputs' do

    it 'parses a deployment log for a node' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1],
        parse_deploy_output: proc do |stdout, stderr|
          expect(stdout.strip).to eq 'Task1: ok'
          expect(stderr.strip).to eq 'Service1 stderr'
          [{ name: 'Task1', status: :identical }]
        end
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node / service1 ] - HPC Service Deploy ===== Begin
          Task1: ok
          ===== [ node / service1 ] - HPC Service Deploy ===== End
          Last log lines
        EOS_STDOUT
        stderr = <<~EOS_STDERR
          ===== [ node / service1 ] - HPC Service Deploy ===== Begin
          Service1 stderr
          ===== [ node / service1 ] - HPC Service Deploy ===== End
        EOS_STDERR
        expect(test_services_handler.parse_deploy_output(stdout, stderr)).to eq [
          {
            node: 'node',
            service: 'service1',
            check: false,
            tasks: [{ name: 'Task1', status: :identical }]
          }
        ]
      end
    end

    it 'parses a deployment log for a node in check mode' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1],
        parse_deploy_output: proc do |stdout, stderr|
          expect(stdout.strip).to eq 'Task1: ok'
          expect(stderr.strip).to eq 'Service1 stderr'
          [{ name: 'Task1', status: :identical }]
        end
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node / service1 ] - HPC Service Check ===== Begin
          Task1: ok
          ===== [ node / service1 ] - HPC Service Check ===== End
          Last log lines
        EOS_STDOUT
        stderr = <<~EOS_STDERR
          ===== [ node / service1 ] - HPC Service Check ===== Begin
          Service1 stderr
          ===== [ node / service1 ] - HPC Service Check ===== End
        EOS_STDERR
        expect(test_services_handler.parse_deploy_output(stdout, stderr)).to eq [
          {
            node: 'node',
            service: 'service1',
            check: true,
            tasks: [{ name: 'Task1', status: :identical }]
          }
        ]
      end
    end

    it 'parses a deployment log for a node even if stderr is empty' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1],
        parse_deploy_output: proc do |stdout, stderr|
          expect(stdout.strip).to eq 'Task1: ok'
          expect(stderr.strip).to eq ''
          [{ name: 'Task1', status: :identical }]
        end
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node / service1 ] - HPC Service Deploy ===== Begin
          Task1: ok
          ===== [ node / service1 ] - HPC Service Deploy ===== End
          Last log lines
        EOS_STDOUT
        expect(test_services_handler.parse_deploy_output(stdout, '')).to eq [
          {
            node: 'node',
            service: 'service1',
            check: false,
            tasks: [{ name: 'Task1', status: :identical }]
          }
        ]
      end
    end

    it 'parses a deployment log for a node deploying several services' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1 service2] } },
        deployable_services: %w[service1 service2],
        parse_deploy_output: proc do |stdout, stderr|
          task_name, status_str = stdout.match(/^(.+?): (.+)$/)[1..2]
          expect(stderr.strip).to eq "#{task_name} stderr"
          [{ name: task_name, status: status_str.to_sym }]
        end
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node / service1 ] - HPC Service Deploy ===== Begin
          Task1: identical
          ===== [ node / service1 ] - HPC Service Deploy ===== End
          Other log lines
          ===== [ node / service2 ] - HPC Service Deploy ===== Begin
          Task2: identical
          ===== [ node / service2 ] - HPC Service Deploy ===== End
          Last log lines
        EOS_STDOUT
        stderr = <<~EOS_STDERR
          ===== [ node / service1 ] - HPC Service Deploy ===== Begin
          Task1 stderr
          ===== [ node / service1 ] - HPC Service Deploy ===== End
          ===== [ node / service2 ] - HPC Service Deploy ===== Begin
          Task2 stderr
          ===== [ node / service2 ] - HPC Service Deploy ===== End
        EOS_STDERR
        expect(test_services_handler.parse_deploy_output(stdout, stderr)).to eq [
          {
            node: 'node',
            service: 'service1',
            check: false,
            tasks: [{ name: 'Task1', status: :identical }]
          },
          {
            node: 'node',
            service: 'service2',
            check: false,
            tasks: [{ name: 'Task2', status: :identical }]
          }
        ]
      end
    end

    it 'parses a deployment log for several nodes deploying several services' do
      with_test_platform(
        nodes: { 'node1' => { services: %w[service1 service2] }, 'node2' => { services: %w[service1 service2] } },
        deployable_services: %w[service1 service2],
        parse_deploy_output: proc do |stdout, stderr|
          task_name, status_str = stdout.match(/^(.+?): (.+)$/)[1..2]
          expect(stderr.strip).to eq "#{task_name} stderr"
          [{ name: task_name, status: status_str.to_sym }]
        end
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node1 / service1 ] - HPC Service Deploy ===== Begin
          Task11: identical
          ===== [ node1 / service1 ] - HPC Service Deploy ===== End
          ===== [ node2 / service2 ] - HPC Service Check ===== Begin
          Task22: identical
          ===== [ node2 / service2 ] - HPC Service Check ===== End
          Other log lines
          ===== [ node1 / service2 ] - HPC Service Deploy ===== Begin
          Task12: identical
          ===== [ node1 / service2 ] - HPC Service Deploy ===== End
          Last log lines
        EOS_STDOUT
        stderr = <<~EOS_STDERR
          ===== [ node1 / service1 ] - HPC Service Deploy ===== Begin
          Task11 stderr
          ===== [ node1 / service1 ] - HPC Service Deploy ===== End
          ===== [ node2 / service2 ] - HPC Service Check ===== Begin
          Task22 stderr
          ===== [ node2 / service2 ] - HPC Service Check ===== End
          ===== [ node1 / service2 ] - HPC Service Deploy ===== Begin
          Task12 stderr
          ===== [ node1 / service2 ] - HPC Service Deploy ===== End
        EOS_STDERR
        expect(test_services_handler.parse_deploy_output(stdout, stderr)).to eq [
          {
            node: 'node1',
            service: 'service1',
            check: false,
            tasks: [{ name: 'Task11', status: :identical }]
          },
          {
            node: 'node2',
            service: 'service2',
            check: true,
            tasks: [{ name: 'Task22', status: :identical }]
          },
          {
            node: 'node1',
            service: 'service2',
            check: false,
            tasks: [{ name: 'Task12', status: :identical }]
          }
        ]
      end
    end

    it 'parses a deployment log for several nodes deploying several services using different platforms' do
      with_test_platforms(
        'platform1' => {
          nodes: { 'node1' => { services: %w[service1 service2] }, 'node2' => { services: %w[service1 service2] } },
          deployable_services: %w[service1],
          parse_deploy_output: proc do |stdout, stderr|
            task_name, status_str = stdout.match(/^(.+?1): (.+)$/)[1..2]
            expect(stderr.strip).to eq "#{task_name} stderr"
            [{ name: task_name, status: status_str.to_sym }]
          end
        },
        'platform2' => {
          nodes: {},
          deployable_services: %w[service2],
          parse_deploy_output: proc do |stdout, stderr|
            task_name, status_str = stdout.match(/^(.+?2): (.+)$/)[1..2]
            expect(stderr.strip).to eq "#{task_name} stderr"
            [{ name: task_name, status: status_str.to_sym }]
          end
        },
      ) do
        stdout = <<~EOS_STDOUT
          First log lines
          ===== [ node1 / service1 ] - HPC Service Deploy ===== Begin
          Task11: identical
          ===== [ node1 / service1 ] - HPC Service Deploy ===== End
          ===== [ node2 / service2 ] - HPC Service Check ===== Begin
          Task22: identical
          ===== [ node2 / service2 ] - HPC Service Check ===== End
          Other log lines
          ===== [ node1 / service2 ] - HPC Service Deploy ===== Begin
          Task12: identical
          ===== [ node1 / service2 ] - HPC Service Deploy ===== End
          Last log lines
        EOS_STDOUT
        stderr = <<~EOS_STDERR
          ===== [ node1 / service1 ] - HPC Service Deploy ===== Begin
          Task11 stderr
          ===== [ node1 / service1 ] - HPC Service Deploy ===== End
          ===== [ node2 / service2 ] - HPC Service Check ===== Begin
          Task22 stderr
          ===== [ node2 / service2 ] - HPC Service Check ===== End
          ===== [ node1 / service2 ] - HPC Service Deploy ===== Begin
          Task12 stderr
          ===== [ node1 / service2 ] - HPC Service Deploy ===== End
        EOS_STDERR
        expect(test_services_handler.parse_deploy_output(stdout, stderr)).to eq [
          {
            node: 'node1',
            service: 'service1',
            check: false,
            tasks: [{ name: 'Task11', status: :identical }]
          },
          {
            node: 'node2',
            service: 'service2',
            check: true,
            tasks: [{ name: 'Task22', status: :identical }]
          },
          {
            node: 'node1',
            service: 'service2',
            check: false,
            tasks: [{ name: 'Task12', status: :identical }]
          }
        ]
      end
    end

  end

end
