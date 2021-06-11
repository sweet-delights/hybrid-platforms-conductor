describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'checking how deployment output is parsed' do

    it 'parses a deployment output properly' do
      with_serverless_chef_platforms('empty') do |platform|
        stdout = <<~EOStdout
          Starting Chef Client, version 14.14.29
          resolving cookbooks for run list: ["policy_xae_websql::xae"]
          Synchronizing Cookbooks:
            - policy_xae_websql (0.1.0)
            - chef-ruby (0.1.2)
            - nginx (10.1.0)
          Installing Cookbook Gems:
          Compiling Cookbooks...
          Recipe: site_debian::default
            * apt_update[apt update] action update
              - force update new lists of packages
              * directory[/etc/apt/apt.conf.d] action create (up to date)
              * file[/etc/apt/apt.conf.d/15update-stamp] action create_if_missing (up to date)
              * execute[apt-get -q update] action run
                - execute ["apt-get", "-q", "update"]
            
            Converging 145 resources
          Recipe: policy_xae_websql::api
            * site_artifactory_dpkg_package[xaecalcite] action install
              * remote_file[/opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb] action create
                - create new file /opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb
                - update content in file /opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb from none to 39b0ca
                (file sizes exceed 10000000 bytes, diff output suppressed)
              * dpkg_package[xaecalcite] action install
                - install version 0.2.4-1 of package xaecalcite
            
            * service[/var/lib/xaecalcite/xaecalcite.service] action enable (skipped due to not_if)

          Running handlers:
          Running handlers complete
          Chef Client finished, 16/300 resources updated in 27 seconds
        EOStdout
        expect(platform.parse_deploy_output(stdout, '')). to eq [
          {
            action: 'update',
            diffs: "force update new lists of packages\n",
            name: 'apt_update[apt update]',
            status: :changed
          },
          {
            action: 'create (up to date)',
            name: 'directory[/etc/apt/apt.conf.d]',
            status: :identical
          },
          {
            action: 'create_if_missing (up to date)',
            name: 'file[/etc/apt/apt.conf.d/15update-stamp]',
            status: :identical
          },
          {
            action: 'run',
            diffs: "execute [\"apt-get\", \"-q\", \"update\"]\n",
            name: 'execute[apt-get -q update]',
            status: :changed
          },
          {
            action: 'install',
            name: 'site_artifactory_dpkg_package[xaecalcite]',
            status: :identical
          },
          {
            action: 'create',
            diffs: <<~EOStdout,
              create new file /opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb
              update content in file /opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb from none to 39b0ca
            EOStdout
            name: 'remote_file[/opt/chef_cache/xaecalcite_0.2.4-1_amd64.deb]',
            status: :changed
          },
          {
            action: 'install',
            diffs: "install version 0.2.4-1 of package xaecalcite\n",
            name: 'dpkg_package[xaecalcite]',
            status: :changed
          },
          {
            action: 'enable (skipped due to not_if)',
            name: 'service[/var/lib/xaecalcite/xaecalcite.service]',
            status: :identical
          }
        ]
      end
    end

  end

end
