yaml_inventory_platform path: "#{Dir.home}/hpc_tutorial/my-service-conf-repo"
for_nodes('web1') do
  expect_tests_to_fail %i[connection], 'web1 is temporarily down - will bring it up later'
end
# Select only the nodes implementing our web-hello service (that is all the webN nodes)
for_nodes [{ service: 'web-hello' }] do
  # On our web servers we should have users used by our services
  check_local_users_do_exist %w[sshd www-data]
  # Make sure we have no leftovers of obsolete users
  check_local_users_do_not_exist %w[dangerous_user obsolete_user]
end
os_image :debian_10, "#{hybrid_platforms_dir}/images/debian_10"
json_bash_platform path: "#{Dir.home}/hpc_tutorial/dev-servers-conf-repo"
