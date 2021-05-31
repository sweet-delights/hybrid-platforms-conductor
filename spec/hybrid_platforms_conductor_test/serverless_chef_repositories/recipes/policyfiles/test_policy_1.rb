name File.basename(__FILE__, '.rb')
default_source :supermarket
default_source :chef_repo, '..'
run_list 'recipe[test_cookbook_1]'
