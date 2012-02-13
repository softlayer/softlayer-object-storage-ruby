# See COPYING for license information.
module SL
  module Storage
    class Container
      # Name of the container which corresponds to the instantiated container class
      attr_reader :name

      # The parent SL::Storage::Connection object for this container
      attr_reader :connection

      # Retrieves an existing SL::Storage::Container object tied to the current SL::Storage::Connection.  If the requested
      # container does not exist, it will raise a SL::Storage::Exception::NoSuchContainer Exception.
      #
      # Will likely not be called directly, instead use connection.container('container_name') to retrieve the object.
      def initialize(connection, name)
        @connection = connection
        @name = name
        # Load the metadata now, so we'll get a SL::Storage::Exception::NoSuchContainer exception should the container
        # not exist.
        self.container_metadata
      end
      
      # Refreshes data about the container and populates class variables. Items are otherwise
      # loaded in a lazy loaded fashion.
      #
      #   container.count
      #   => 2
      #   [Upload new file to the container]
      #   container.count
      #   => 2
      #   container.populate
      #   container.count
      #   => 3
      def refresh
        @metadata = @cdn_metadata = nil
        true
      end
      alias :populate :refresh

      # Retrieves Metadata for the container
      def container_metadata
        @metadata ||= (
          response = SL::Swift::Client.head_container(self.connection.storageurl, self.connection.authtoken, escaped_name)
          resphash = {}
          response.to_hash.select { |k,v| k.match(/^x-container-meta/) }.each { |x| resphash[x[0]] = x[1].to_s }
          {:bytes => response["x-container-bytes-used"].to_i, :count => response["x-container-object-count"].to_i, :metadata => resphash, :container_read => response["x-container-read"], :container_write => response["x-container-write"]}
        )
      end

      # Retrieves CDN-Enabled Meta Data
      def cdn_metadata
        @cdn_metadata ||= (
          response = SL::Swift::Client.head_container(self.connection.storageurl, self.connection.authtoken, escaped_name, nil, true)
          resphash = {}
          response.to_hash.select { |k,v| k.match(/^x-cdn/i) }
        )
      end
      
      # Returns the container's metadata as a nicely formatted hash, stripping off the X-Meta-Object- prefix that the system prepends to the
      # key name.
      #
      #    object.metadata
      #    => {"ruby"=>"cool", "foo"=>"bar"}
      def metadata
        metahash = {}
        self.container_metadata[:metadata].each{ |key, value| metahash[key.gsub(/x-container-meta-/, '').gsub(/%20/, ' ')] = URI.decode(value).gsub(/\+\-/, ' ') }
        metahash
      end

      # Sets the metadata for an object.  By passing a hash as an argument, you can set the metadata for an object.
      # New calls to set metadata are additive.  To remove metadata, set the value of the key to nil.  
      #
      # Throws NoSuchObjectException if the container doesn't exist.  Throws InvalidResponseException if the request
      # fails.
      def set_metadata(metadatahash)
        headers = {}
        metadatahash.each{ |key, value| headers['X-Container-Meta-' + SL::Storage.escape(key.to_s.capitalize)] = value.to_s }
        begin
          SL::Swift::Client.post_container(self.connection.storageurl, self.connection.authtoken, escaped_name, headers)
          self.refresh
          true
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchObject, "Container #{@name} does not exist" if (e.status.to_s == "404")
          raise SL::Storage::Exception::InvalidResponse, "Invalid response code #{e.status}" unless (e.status.to_s =~ /^20/)
        end
      end
      
      # Size of the container (in bytes)
      def bytes
        self.container_metadata[:bytes]
      end

      # Number of objects in the container
      def count
        self.container_metadata[:count]
      end

      # Returns true if the container is public and CDN-enabled.  Returns false otherwise.
      #
      # Aliased as container.public?
      #
      #   public_container.cdn_enabled?
      #   => true
      #
      #   private_container.public?
      #   => false
      def cdn_enabled
        cdn_available? && self.cdn_metadata[:cdn_enabled]
      end
      alias :cdn_enabled? :cdn_enabled
      alias :public? :cdn_enabled

      # CDN container TTL (if container is public)
      def cdn_ttl
        self.cdn_metadata[:cdn_ttl]
      end


      def cdn_urls
        @cdn_urls ||= (
          container_metadata.select{|k,v| k.match(/^x-cdn[\w-]*/) }
        )
      end

      #used by openstack swift
      def read_acl
        self.container_metadata[:container_read]
      end

      #used by openstack swift
      def write_acl
        self.container_metadata[:container_write]
      end

      # Returns true if log retention is enabled on this container, false otherwise
      def cdn_log
        self.cdn_metadata[:cdn_log]
      end
      alias :log_retention? :cdn_log
      alias :cdn_log? :cdn_log


      # Change the log retention status for this container.  Values are true or false.
      #
      # These logs will be periodically (at unpredictable intervals) compressed and uploaded
      # to a ".CDN_ACCESS_LOGS" container in the form of "container_name.YYYYMMDDHH-XXXX.gz".
      def log_retention=(value)
        raise Exception::CDNNotAvailable unless cdn_available?
        begin
          SL::Swift::Client.post_container(self.connection.cdnurl, self.connection.authtoken, escaped_name, {"x-log-retention" => value.to_s.capitalize})
          true
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::InvalidResponse, "Invalid response code #{e.status}" unless (e.status.to_s == "201" or e.status.to_s == "202")
        end
      end


      # Returns the SL::Storage::StorageObject for the named object.  Refer to the SL::Storage::StorageObject class for available
      # methods.  If the object exists, it will be returned.  If the object does not exist, a NoSuchObjectException will be thrown.
      #
      #   object = container.object('test.txt')
      #   object.data
      #   => "This is test data"
      #
      #   object = container.object('newfile.txt')
      #   => NoSuchObjectException: Object newfile.txt does not exist
      def object(objectname)
        o = SL::Storage::StorageObject.new(self, objectname, true)
        return o
      end
      alias :get_object :object


      # Gathers a list of all available objects in the current container and returns an array of object names.
      #   container = cf.container("My Container")
      #   container.objects                     #=> [ "cat", "dog", "donkey", "monkeydir", "monkeydir/capuchin"]
      # Pass a limit argument to limit the list to a number of objects:
      #   container.objects(:limit => 1)                  #=> [ "cat" ]
      # Pass an marker with or without a limit to start the list at a certain object:
      #   container.objects(:limit => 1, :marker => 'dog')                #=> [ "donkey" ]
      # Pass a prefix to search for objects that start with a certain string:
      #   container.objects(:prefix => "do")       #=> [ "dog", "donkey" ]
      # Only search within a certain pseudo-filesystem path:
      #   container.objects(:path => 'monkeydir')     #=> ["monkeydir/capuchin"]
      # Only grab "virtual directories", based on a single-character delimiter (no "directory" objects required):
      #   container.objects(:delimiter => '/')      #=> ["monkeydir"]
      # All arguments to this method are optional.
      #
      # Returns an empty array if no object exist in the container.  Throws an InvalidResponseException
      # if the request fails.
      def objects(params = {})
        params[:marker] ||= params[:offset] unless params[:offset].nil?
        query = []
        params.each do |param, value|
          if [:limit, :marker, :prefix, :path, :delimiter].include? param
            query << "#{param}=#{SL::Storage.escape(value.to_s)}"
          end
        end
        begin
          response = SL::Swift::Client.get_container(self.connection.storageurl, self.connection.authtoken, escaped_name, params[:marker], params[:limit], params[:prefix], params[:delimiter])
          return response[1].collect{|o| o['name']}
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::InvalidResponse, "Invalid response code #{e.status}" unless (e.status.to_s == "200")
        end
      end
      alias :list_objects :objects

      def search(options = {})
        
      end

      # Retrieves a list of all objects in the current container along with their size in bytes, hash, and content_type.
      # If no objects exist, an empty hash is returned.  Throws an InvalidResponseException if the request fails.  Takes a
      # parameter hash as an argument, in the same form as the objects method.
      #
      # Accepts the same options as objects to limit the returned set.
      #
      # Returns a hash in the same format as the containers_detail from the SL::Storage class.
      #
      #   container.objects_detail
      #   => {"test.txt"=>{:content_type=>"application/octet-stream",
      #                    :hash=>"e2a6fcb4771aa3509f6b27b6a97da55b",
      #                    :last_modified=>Mon Jan 19 10:43:36 -0600 2009,
      #                    :bytes=>"16"},
      #       "new.txt"=>{:content_type=>"application/octet-stream",
      #                   :hash=>"0aa820d91aed05d2ef291d324e47bc96",
      #                   :last_modified=>Wed Jan 28 10:16:26 -0600 2009,
      #                   :bytes=>"22"}
      #      }
      def objects_detail(params = {})
        params[:marker] ||= params[:offset] unless params[:offset].nil?
        query = ["format=xml"]
        params.each do |param, value|
          if [:limit, :marker, :prefix, :path, :delimiter].include? param
            query << "#{param}=#{SL::Storage.escape(value.to_s)}"
          end
        end
        begin 
          response = SL::Swift::Client.get_container(self.connection.storageurl, self.connection.authtoken, escaped_name, params[:marker], params[:limit], params[:prefix], params[:delimiter])
          return Hash[*response[1].collect{|o| [o['name'],{ :bytes => o["bytes"], :hash => o["hash"], :content_type => o["content_type"], :last_modified => DateTime.parse(o["last_modified"])}] }.flatten]
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::InvalidResponse, "Invalid response code #{e.status}" unless (e.status.to_s == "200")
        end
      end
      alias :list_objects_info :objects_detail

      # Returns true if a container is empty and returns false otherwise.
      #
      #   new_container.empty?
      #   => true
      #
      #   full_container.empty?
      #   => false
      def empty?
        return (container_metadata[:count].to_i == 0)? true : false
      end

      # Returns true if object exists and returns false otherwise.
      #
      #   container.object_exists?('goodfile.txt')
      #   => true
      #
      #   container.object_exists?('badfile.txt')
      #   => false
      def object_exists?(objectname)
        begin
          response = SL::Swift::Client.head_object(self.connection.storageurl, self.connection.authtoken, escaped_name, objectname)
          true
        rescue SL::Swift::ClientException => e
          false
        end
      end

      # Creates a new SL::Storage::StorageObject in the current container.
      #
      # If an object with the specified name exists in the current container, that object will be returned.  Otherwise,
      # an empty new object will be returned.
      #
      # Passing in the optional make_path argument as true will create zero-byte objects to simulate a filesystem path
      # to the object, if an objectname with path separators ("/path/to/myfile.mp3") is supplied.  These path objects can
      # be used in the Container.objects method.
      def create_object(objectname, make_path = false)
        SL::Storage::StorageObject.new(self, objectname, false, make_path)
      end

      # Removes an SL::Storage::StorageObject from a container.  True is returned if the removal is successful.  Throws
      # NoSuchObjectException if the object doesn't exist.  Throws InvalidResponseException if the request fails.
      #
      #   container.delete_object('new.txt')
      #   => true
      #
      #   container.delete_object('nonexistent_file.txt')
      #   => NoSuchObjectException: Object nonexistent_file.txt does not exist
      def delete_object(objectname)
        begin
          SL::Swift::Client.delete_object(self.connection.storageurl, self.connection.authtoken, escaped_name, SL::Storage.escape(objectname))
          true
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchObject, "Object #{objectname} does not exist" if (e.status.to_s == "404")
          raise SL::Storage::Exception::InvalidResponse, "Invalid response code #{e.status}" unless (e.status.to_s =~ /^20/)
        end
      end

      def set_ttl(ttl)
        begin
          SL::Swift::Client.put_container(self.connection.storageurl, self.connection.authtoken, escaped_name)
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist" unless (e.status.to_s == "201" || e.status.to_s == "202")
        end
        headers = { 
          "X-Context" => "cdn",
          "X-Cdn-Ttl" => ttl.to_s
        }

        post_with_headers(headers)
        # raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist" unless (response.code == "201" || response.code == "202")
        refresh
        true
      end

      def make_public(ttl = 4600)
        begin
          SL::Swift::Client.put_container(self.connection.storageurl, self.connection.authtoken, escaped_name)
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist" unless (e.status.to_s == "201" || e.status.to_s == "202")
        end
        headers = { 
          "X-Context" => "cdn",
          "X-Container-Read" => ".r:*",
          "X-Cdn-Ttl" => ttl.to_s
        }

        post_with_headers(headers)
        # raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist" unless (response.code == "201" || response.code == "202")
        refresh
        true
      end

      # Only to be used with openstack swift
      def set_write_acl(write_string)
        refresh
        headers = {"X-Container-Write" => write_string}
        post_with_headers(headers)
        true
      end

      # Only to be used with openstack swift
      def set_read_acl(read_string)
        refresh
        headers = {"X-Container-Read" => read_string}
        post_with_headers(headers)
        true
      end

      def post_with_headers(headers = {})
        begin
          SL::Swift::Client.post_container(self.connection.storageurl, self.connection.authtoken, escaped_name, headers)
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist (response code: #{e.status.to_s})" unless (e.status.to_s =~ /^20/)
        end
      end
     
      # Makes a container private and returns true upon success.  Throws NoSuchContainerException
      # if the container doesn't exist or if the request fails.
      #
      # Note that if the container was previously public, it will continue to exist out on the CDN until it expires.
      #
      #   container.make_private
      #   => true
      def make_private
        raise Exception::CDNNotAvailable unless cdn_available?
        headers = { 
          "X-Context" => "cdn",
          "X-Container-Read" => " "
        }
        begin
          SL::Swift::Client.post_container(self.connection.storageurl, self.connection.authtoken, escaped_name, headers)
          refresh
          true
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::NoSuchContainer, "Container #{@name} does not exist" unless (e.status.to_s == "201" || e.status.to_s == "202")
        end
      end

      # Purges CDN Edge Cache for all objects inside of this container
      #
      # :email, An valid email address or comma seperated 
      #  list of emails to be notified once purge is complete .
      #
      #   container.purge_from_cdn
      #   => true
      #
      #  or 
      #   
      #   container.purge_from_cdn("User@domain.com")
      #   => true
      #
      #  or
      #
      #   container.purge_from_cdn("User@domain.com, User2@domain.com")
      #   => true
      def purge_from_cdn(email=nil)
        raise Exception::CDNNotAvailable unless cdn_available?
        headers = {}
        headers = {"X-Purge-Email" => email} if email
        begin
          SL::Swift::Client.delete_container(self.connection.cdnurl, self.connection.authtoken, escaped_name, headers)
          true
        rescue SL::Swift::ClientException => e
          raise SL::Storage::Exception::Connection, "Error Unable to Purge Container: #{@name}" unless (e.status.to_s > "200" && e.status.to_s < "299")
        end
      end

      def to_s # :nodoc:
        @name
      end

      def cdn_available?
        true
      end
      
      def escaped_name
        SL::Storage.escape(@name)
      end

    end

  end
end
