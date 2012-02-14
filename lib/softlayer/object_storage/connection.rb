# See COPYING for license information.
module SoftLayer
  module ObjectStorage
    class Connection

      # Authentication key provided when the SoftLayer::ObjectStorage class was instantiated
      attr_reader :authkey

      # Token returned after a successful authentication
      attr_accessor :authtoken

      # Authentication username provided when the SoftLayer::ObjectStorage class was instantiated
      attr_reader :authuser

      # API host to authenticate to
      attr_reader :auth_url

      # Set at auth to see if a CDN is available for use
      attr_accessor :cdn_available
      alias :cdn_available? :cdn_available

      # Hostname of the CDN management server
      attr_accessor :cdnmgmthost

      # Path for managing containers on the CDN management server
      attr_accessor :cdnmgmtpath

      # Port number for the CDN server
      attr_accessor :cdnmgmtport

      # URI scheme for the CDN server
      attr_accessor :cdnmgmtscheme

      # Hostname of the storage server
      attr_accessor :storagehost

      # Path for managing containers/objects on the storage server
      attr_accessor :storagepath

      # Port for managing the storage server
      attr_accessor :storageport

      # URI scheme for the storage server
      attr_accessor :storagescheme

      # Instance variable that is set when authorization succeeds
      attr_accessor :authok

      # Optional proxy variables
      attr_reader :proxy_host
      attr_reader :proxy_port

      attr_reader :client

      def initialize(options = {})
        options = options.dup
        protocol = options.delete(:protocol) {:https}
        datacenter = options.delete(:datacenter) { raise ":datacenter is a required option"}
        network = options.delete(:network) {:public}

        @authuser = options[:username] ||( raise SoftLayer::ObjectStorage::Exception::Authentication, "Must supply a :username")
        @authkey = options[:api_key] || (raise SoftLayer::ObjectStorage::Exception::Authentication, "Must supply an :api_key")
        @auth_url = SoftLayer::ObjectStorage::ENDPOINTS[datacenter][network][protocol]  
        @retry_auth = options[:retry_auth] || true
        @proxy_host = options[:proxy_host]
        @proxy_port = options[:proxy_port]
        @authok = false
        @http = {}
        SoftLayer::ObjectStorage::Authentication.new(self)
      end

      def authok?
        @authok
      end

      def container(name)
        SoftLayer::ObjectStorage::Container.new(self, name)
      end
      alias :get_container :container


      def search(options = {})
          response = SoftLayer::Swift::Client.search(storageurl, options, self.authtoken )
      end

      def get_info
        begin
          raise SoftLayer::ObjectStorage::Exception::AuthenticationException, "Not authenticated" unless self.authok?
          response = SoftLayer::Swift::Client.head_account(storageurl, self.authtoken)
          @bytes = response["x-account-bytes-used"].to_i
          @count = response["x-account-container-count"].to_i
          {:bytes => @bytes, :count => @count}
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Unable to obtain account size" unless (e.status.to_s == "204")
        end
      end
      
      def bytes
        get_info[:bytes]
      end
      
      def count
        get_info[:count]
      end

      def containers(limit = nil, marker = nil)
        begin
          response = SoftLayer::Swift::Client.get_account(storageurl, self.authtoken, marker, limit)
          response[1].collect{|c| c['name']}
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{e.status.to_s}" unless (e.status.to_s == "200")
        end
      end
      alias :list_containers :containers

      def containers_detail(limit = nil, marker = nil)
        begin
          response = SoftLayer::Swift::Client.get_account(storageurl, self.authtoken, marker, limit)
          Hash[*response[1].collect{|c| [c['name'], {:bytes => c['bytes'], :count => c['count']}]}.flatten]
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{e.status.to_s}" unless (e.status.to_s == "200")
        end
      end
      alias :list_containers_info :containers_detail

      def container_exists?(containername)
        begin
          response = SoftLayer::Swift::Client.head_container(storageurl, self.authtoken, containername)
          true
        rescue SoftLayer::Swift::ClientException => e
          false
        end
      end

      def create_container(containername)
        raise SoftLayer::ObjectStorage::Exception::Syntax, "Container name cannot contain '/'" if containername.match("/")
        raise SoftLayer::ObjectStorage::Exception::Syntax, "Container name is limited to 256 characters" if containername.length > 256
          SoftLayer::Swift::Client.put_container(storageurl, self.authtoken, SoftLayer::ObjectStorage.escape(containername))
          SoftLayer::ObjectStorage::Container.new(self, containername)
      end

      def delete_container(containername, recursive = false)
        begin
          SoftLayer::Swift::Client.delete_container(storageurl, self.authtoken, SoftLayer::ObjectStorage.escape(containername), {}, nil, recursive)
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::NonEmptyContainer, "Container #{containername} is not empty" if (e.status.to_s == "409")
          raise SoftLayer::ObjectStorage::Exception::NoSuchContainer, "Container #{containername} does not exist" unless (e.status.to_s == "204")
        end
        true
      end

      def public_containers(enabled_only = false)
        begin
          response = SoftLayer::Swift::Client.get_account(storageurl, self.authtoken, nil, nil, nil, nil, nil, true)
          response[1].collect{|c| c['name']}
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{e.status.to_s}" unless (e.status.to_s == "200")
        end
      end
      
      def storageurl
        "#{self.storagescheme}://#{self.storagehost}:#{self.storageport.to_s}#{self.storagepath}"
      end
    end
  end
end
