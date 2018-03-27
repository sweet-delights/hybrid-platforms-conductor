module HybridPlatformsConductor

  class Topographer

    # Base class of any topographer plugin
    class Plugin

      # Constructor
      #
      # Parameters::
      # * *topographer* (Topographer): Topographer instance containing the graph to be output
      def initialize(topographer)
        @topographer = topographer
      end

    end

  end

end
