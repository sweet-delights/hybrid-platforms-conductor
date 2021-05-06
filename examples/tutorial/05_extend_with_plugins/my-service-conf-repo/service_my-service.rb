# Get the wanted content of the configuration file as a String, based on the node's metadata
#
# Parameters::
# * *node* (String): Node for which we configure our service
# Result::
# * String: The wanted content
def wanted_conf_for(node)
  # We will access the node's metadata using the NodesHandler API, through the @nodes_handler object
  @service_port = @nodes_handler.get_service_port_of(node)
  @service_timeout = @nodes_handler.get_service_timeout_of(node)
  # We use erubis to generate the configuration from our eRuby template, and return it directly
  Erubis::Eruby.new(File.read("#{@platform_handler.repository_path}/my-service.conf.erb")).result(binding)
end

# Get actions to check the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we check the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def check(node)
  # We first dump the wanted content in a temporary file and then we diff it.
  [
    {
      remote_bash: <<~EOS
        cat <<EOF >/tmp/my-service.conf.wanted
        #{wanted_conf_for(node)}
        EOF
        echo Diffs on my-service.conf:
        if test -f ~/hpc_tutorial/node/my-service.conf; then
          diff ~/hpc_tutorial/node/my-service.conf /tmp/my-service.conf.wanted || true
        else
          echo "Create file from scratch"
          cat /tmp/my-service.conf.wanted
        fi
      EOS
    }
  ]
end

# Get actions to deploy the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we deploy the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def deploy(node)
  # We first check, as this will display diffs and prepare the file to be copied.
  # And then we really deploy the file on our node.
  check(node) + [
    {
      remote_bash: <<~EOS
        mkdir -p ~/hpc_tutorial/node
        cp /tmp/my-service.conf.wanted ~/hpc_tutorial/node/my-service.conf
      EOS
    }
  ]
end
