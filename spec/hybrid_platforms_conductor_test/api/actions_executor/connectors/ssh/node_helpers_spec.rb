describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking connector plugin ssh' do

    context 'checking additional helpers on prepared nodes' do

      it 'provides an SSH executable wrapping the node\'s SSH config' do
        with_test_platform_for_remote_testing do
          expect(`#{test_connector.ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{test_connector.ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
        end
      end

      it 'provides an SSH URL that can be used by other processes to connect to this node' do
        with_test_platform_for_remote_testing do
          expect(test_connector.ssh_url).to eq 'hpc.node'
        end
      end

      it 'uses sshpass in the provided SSH executable if needed' do
        with_test_platform_for_remote_testing(password: 'PaSsWoRd') do
          expect(`#{test_connector.ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{test_connector.ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
          expect(File.read(test_connector.ssh_exec)).to match /^sshpass -pPaSsWoRd ssh .+$/
        end
      end

    end

  end

end
