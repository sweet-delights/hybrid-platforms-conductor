cookbook_path %w[cookbooks] + (ENV['hpc_test_cookbooks_path'] ? ENV['hpc_test_cookbooks_path'].split(':') : [])
