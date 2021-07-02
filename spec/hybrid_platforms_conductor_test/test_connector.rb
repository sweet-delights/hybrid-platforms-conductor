module HybridPlatformsConductorTest

  # Test connector
  class TestConnector < HybridPlatformsConductor::Connector

    # Array<Object<: Access calls made to the test connector
    attr_reader :calls

    # Array<String>: List of nodes accepted by this connector
    attr_accessor :accept_nodes

    # Array<String> or nil: List of nodes that will be connected, or nil for all
    attr_accessor :connected_nodes

    # Proc: Code executed when remote_bash is called
    # Parameters::
    # * *stdout* (IO): stdout to return
    # * *stderr* (IO): stderr to return
    # * *connector* (TestConnector): The current connector
    attr_accessor :remote_bash_code

    # Proc: Code executed when remote_copy is called
    # Parameters::
    # * *stdout* (IO): stdout to return
    # * *stderr* (IO): stderr to return
    # * *connector* (TestConnector): The current connector
    attr_accessor :remote_copy_code

    # Initialize the connector.
    # This can be used to initialize global variables that are used for this connector
    # [API] - This method is optional
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    def init
      @calls = []
      @accept_nodes = []
      @connected_nodes = nil
      @remote_bash_code = nil
      @remote_copy_code = nil
    end

    # Complete an option parser with options meant to control this connector
    # [API] - This method is optional
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(_options_parser)
      @calls << [:options_parse]
    end

    # Validate that parsed parameters are valid
    # [API] - This method is optional
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    def validate_params
      @calls << [:validate_params]
    end

    # Select nodes where this connector can connect.
    # [API] - This method is mandatory
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    #
    # Parameters::
    # * *nodes* (Array<String>): List of candidate nodes
    # Result::
    # * Array<String>: List of nodes we can connect to from the candidates
    def connectable_nodes_from(nodes)
      @calls << [:connectable_nodes_from, nodes]
      nodes & @accept_nodes
    end

    # Prepare connections to a given set of nodes.
    # Useful to prefetch metadata or open bulk connections.
    # [API] - This method is optional
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes to prepare the connection to
    # * *no_exception* (Boolean): Should we still continue if some nodes have connection errors? [default: false]
    # * Proc: Code called with the connections prepared.
    #   * Parameters::
    #     * *connected_nodes* (Array<String>): The list of connected nodes (should be equal to nodes unless no_exception == true and some nodes failed to connect)
    def with_connection_to(nodes, no_exception: false)
      @calls << [:with_connection_to, nodes, { no_exception: no_exception }]
      yield @connected_nodes.nil? ? nodes : @connected_nodes
    end

    # Run bash commands on a given node.
    # [API] - This method is mandatory
    # [API] - If defined, then with_connection_to has been called before this method.
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    # [API] - @node can be used to access the node on which we execute the remote bash
    # [API] - @timeout can be used to know when the action should fail
    # [API] - @stdout_io can be used to send stdout output
    # [API] - @stderr_io can be used to send stderr output
    #
    # Parameters::
    # * *bash_cmds* (String or SecretString): Bash commands to execute. Use #to_unprotected to access the real content (otherwise secrets are obfuscated).
    def remote_bash(bash_cmds)
      @calls << [:remote_bash, bash_cmds.to_unprotected.clone]
      @remote_bash_code&.call(@stdout_io, @stderr_io, self)
    end

    # Execute an interactive shell on the remote node
    # [API] - This method is mandatory
    # [API] - If defined, then with_connection_to has been called before this method.
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    # [API] - @node can be used to access the node on which we execute the remote bash
    # [API] - @timeout can be used to know when the action should fail
    # [API] - @stdout_io can be used to send stdout output
    # [API] - @stderr_io can be used to send stderr output
    def remote_interactive
      @calls << [:remote_interactive]
    end

    # Copy a file to the remote node in a directory
    # [API] - This method is mandatory
    # [API] - If defined, then with_connection_to has been called before this method.
    # [API] - @cmd_runner can be used
    # [API] - @nodes_handler can be used
    # [API] - @node can be used to access the node on which we execute the remote bash
    # [API] - @timeout can be used to know when the action should fail
    # [API] - @stdout_io can be used to send stdout output
    # [API] - @stderr_io can be used to send stderr output
    #
    # Parameters::
    # * *from* (String): Local file to copy
    # * *to* (String): Remote directory to copy to
    # * *sudo* (Boolean): Do we use sudo to copy? [default: false]
    # * *owner* (String or nil): Owner to be used when copying the files, or nil for current one [default: nil]
    # * *group* (String or nil): Group to be used when copying the files, or nil for current one [default: nil]
    def remote_copy(from, to, sudo: false, owner: nil, group: nil)
      extra_opts = {}
      extra_opts[:sudo] = sudo if sudo
      extra_opts[:owner] = owner if owner
      extra_opts[:group] = group if group
      @calls << [:remote_copy, from, to] + (extra_opts.empty? ? [] : [extra_opts])
      @remote_copy_code&.call(@stdout_io, @stderr_io, self)
    end

    # Integer: The current desired timeout
    attr_reader :timeout

  end

end
