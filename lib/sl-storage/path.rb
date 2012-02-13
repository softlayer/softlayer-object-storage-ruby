# See COPYING for license information.
module SL
  module Storage
    class Path
    
      attr_reader :container
      attr_reader :path
      def initialize(container, path = '')
        @container = container
        @path = path
      end

      def objects
        container.objects(:path => path)
      end

      def search(options)
        container.search(:path => path, options)
      end

    end
  end
end
