# Get actions to check the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we check the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def check(node)
  # We first dump the wanted content in a temporary file and then we diff it.
  # We will access the node's planet, hostname and IP from its metadata using the NodesHandler API, through the @nodes_handler object
  [
    {
      remote_bash: <<~EOS
        echo 'Hello #{@nodes_handler.get_planet_of(node) || 'World'} from #{@nodes_handler.get_hostname_of(node)} (#{@nodes_handler.get_host_ip_of(node)})' >/tmp/hello_world.txt.wanted
        echo Diffs on hello_world.txt:
        if test -f /root/hello_world.txt; then
          diff /root/hello_world.txt /tmp/hello_world.txt.wanted || true
        else
          echo "Create hello_world.txt from scratch"
          cat /tmp/hello_world.txt.wanted
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
        cp /tmp/hello_world.txt.wanted /root/hello_world.txt
      EOS
    }
  ]
end
