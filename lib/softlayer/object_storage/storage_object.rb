# See COPYING for license information.
module SoftLayer
  module ObjectStorage
    class StorageObject

      # Name of the object corresponding to the instantiated object
      attr_reader :name
      
      # The parent SoftLayer::ObjectStorage::Container object
      attr_reader :container

      # Builds a new SoftLayer::ObjectStorage::StorageObject in the current container.  If force_exist is set, the object must exist or a
      # SoftLayer::ObjectStorage::Exception::NoSuchObject Exception will be raised.  If not, an "empty" SoftLayer::ObjectStorage::StorageObject will be returned, ready for data
      # via SoftLayer::ObjectStorage::StorageObject.write
      def initialize(container, objectname, force_exists = false, make_path = false)
        @container = container
        @containername = container.name
        @name = objectname
        @make_path = make_path
        @storagepath = "#{container.escaped_name}/#{escaped_name}"

        if force_exists
          raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" unless container.object_exists?(escaped_name)
        end
      end

      # Refreshes the object metadata
      def refresh
        @object_metadata = nil
        true
      end
      alias :populate :refresh

      # Retrieves Metadata for the object
      def object_metadata
        @object_metadata ||= (
          begin
            response = SoftLayer::Swift::Client.head_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name)
          rescue SoftLayer::Swift::ClientException => e
            raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" unless (e.status.to_s =~ /^20/)
          end
          resphash = {}
          metas = response.to_hash.select { |k,v| k.match(/^x-object-meta/) }

          metas.each do |x,y|
            resphash[x] = (y.respond_to?(:join) ? y.join('') : y.to_s)
          end

          {
            :manifest => response["x-object-manifest"],
            :bytes => response["content-length"],
            :last_modified => Time.parse(response["last-modified"]),
            :etag => response["etag"],
            :content_type => response["content-type"],
            :metadata => resphash
          }
        )
      end

      # Retrieves CDN-Enabled Meta Data
      def cdn_metadata
        @cdn_metadata ||= (
          response = SoftLayer::Swift::Client.head_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name)
          resphash = {}
          response.to_hash.select { |k,v| k.match(/^x-cdn/i) }
        )
      end

      def escaped_name
        @escaped_name ||= escape_name @name
      end

      # Size of the object (in bytes)
      def bytes
        self.object_metadata[:bytes]
      end

      # Date of the object's last modification
      def last_modified
        self.object_metadata[:last_modified]
      end

      # ETag of the object data
      def etag
        self.object_metadata[:etag]
      end

      # Content type of the object data
      def content_type
        self.object_metadata[:content_type]
      end

      def content_type=(type)
        self.copy(:headers => {'Content-Type' => type})
      end
   
      # Retrieves the data from an object and stores the data in memory.  The data is returned as a string.
      # Throws a NoSuchObjectException if the object doesn't exist.
      #
      # If the optional size and range arguments are provided, the call will return the number of bytes provided by
      # size, starting from the offset provided in offset.
      #
      #   object.data
      #   => "This is the text stored in the file"
      def data(size = -1, offset = 0, headers = {})
        if size.to_i > 0
          range = sprintf("bytes=%d-%d", offset.to_i, (offset.to_i + size.to_i) - 1)
          headers['Range'] = range
        end
        begin
          response = SoftLayer::Swift::Client.get_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name)
          response[1]
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" unless (e.status.to_s =~ /^20/)
        end
      end
      alias :read :data

      # Retrieves the data from an object and returns a stream that must be passed to a block.  Throws a
      # NoSuchObjectException if the object doesn't exist.
      #
      # If the optional size and range arguments are provided, the call will return the number of bytes provided by
      # size, starting from the offset provided in offset.
      #
      #   data = ""
      #   object.data_stream do |chunk|
      #     data += chunk
      #   end
      #
      #   data
      #   => "This is the text stored in the file"
      def data_stream(size = -1, offset = 0, headers = {}, &block)
        if size.to_i > 0
          range = sprintf("bytes=%d-%d", offset.to_i, (offset.to_i + size.to_i) - 1)
          headers['Range'] = range
        end
        begin
          SoftLayer::Swift::Client.get_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, nil, nil, &block)
        end
      end

      # Returns the object's metadata as a nicely formatted hash, stripping off the X-Meta-Object- prefix that the system prepends to the
      # key name.
      #
      #    object.metadata
      #    => {"ruby"=>"cool", "foo"=>"bar"}
      def metadata
        metahash = {}
        self.object_metadata[:metadata].each{ |key, value| metahash[key.gsub(/x-object-meta-/, '').gsub(/\+\-/, ' ')] = URI.decode(value).gsub(/\+\-/, ' ') }
        metahash
      end

      # Sets the metadata for an object.  By passing a hash as an argument, you can set the metadata for an object.
      # However, setting metadata will overwrite any existing metadata for the object.
      #
      # Throws NoSuchObjectException if the object doesn't exist.  Throws InvalidResponseException if the request
      # fails.
      def set_metadata(metadatahash)
        headers = {}
        metadatahash.each{ |key, value| headers['X-Object-Meta-' + key.to_s.capitalize] = value.to_s }
        begin
          SoftLayer::Swift::Client.post_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, headers)
          true
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" if (e.status.to_s == "404")
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{e.status.to_s}" unless (e.status.to_s =~ /^20/)
          false
        end
      end
      alias :metadata= :set_metadata

      def set_ttl(ttl)
        headers = {"X-Cdn-Ttl" => ttl.to_s}
        begin
          SoftLayer::Swift::Client.post_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, headers)
          true
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" if (e.status.to_s == "404")
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{e.status.to_s}" unless (e.status.to_s =~ /^20/)
          false
        end
      end


      def purge
        headers = {
          "X-Context" => "cdn",
          "X-Cdn-Purge" => "true"
        }
          SoftLayer::Swift::Client.post_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, headers)
          true
      end

      

      # Returns the object's manifest.
      #
      #    object.manifest
      #    => "container/prefix"
      def manifest
        self.object_metadata[:manifest]
      end


      # Sets the manifest for an object.  By passing a string as an argument, you can set the manifest for an object.
      # However, setting manifest will overwrite any existing manifest for the object.
      #
      # Throws NoSuchObjectException if the object doesn't exist.  Throws InvalidResponseException if the request
      # fails.
      def set_manifest(manifest)
        headers = {'X-Object-Manifest' => manifest}
        begin
          SoftLayer::Swift::Client.post_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, headers)
          true
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::NoSuchObject, "Object #{@name} does not exist" if (response.code == "404")
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{response.code}" unless (response.code =~ /^20/)
          false
        end
      end


      # Takes supplied data and writes it to the object, saving it.  You can supply an optional hash of headers, including
      # Content-Type and ETag, that will be applied to the object.
      #
      # If you would rather stream the data in chunks, instead of reading it all into memory at once, you can pass an
      # IO object for the data, such as: object.write(open('/path/to/file.mp3'))
      #
      # You can compute your own MD5 sum and send it in the "ETag" header.  If you provide yours, it will be compared to
      # the MD5 sum on the server side.  If they do not match, the server will return a 422 status code and a SoftLayer::ObjectStorage::Exception::MisMatchedChecksum Exception
      # will be raised.  If you do not provide an MD5 sum as the ETag, one will be computed on the server side.
      #
      # Updates the container cache and returns true on success, raises exceptions if stuff breaks.
      #
      #   object = container.create_object("newfile.txt")
      #
      #   object.write("This is new data")
      #   => true
      #
      #   object.data
      #   => "This is new data"
      #
      # If you are passing your data in via STDIN, just do an
      #
      #   object.write
      #
      # with no data (or, if you need to pass headers)
      #
      #  object.write(nil,{'header' => 'value})

      def write(data = nil, headers = {})
        raise SoftLayer::ObjectStorage::Exception::Syntax, "No data or header updates supplied" if ((data.nil? && $stdin.tty?) and headers.empty?)
        # If we're taking data from standard input, send that IO object to cfreq
        data = $stdin if (data.nil? && $stdin.tty? == false)
        begin
          response = SoftLayer::Swift::Client.put_object(self.container.connection.storageurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, data, nil, nil, nil, nil, headers)
        rescue SoftLayer::Swift::ClientException => e
          code = e.status.to_s
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid content-length header sent" if (code == "412")
          raise SoftLayer::ObjectStorage::Exception::MisMatchedChecksum, "Mismatched etag" if (code == "422")
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{code}" unless (code =~ /^20./)
        end
        make_path(File.dirname(self.name)) if @make_path == true
        self.refresh
        true
      end
      # Purges CDN Edge Cache for all objects inside of this container
      # 
      # :email, An valid email address or comma seperated 
      # list of emails to be notified once purge is complete .
      #
      #    obj.purge_from_cdn
      #    => true
      #
      #  or 
      #                                     
      #   obj.purge_from_cdn("User@domain.com")
      #   => true
      #                                                
      #  or
      #                                                         
      #   obj.purge_from_cdn("User@domain.com, User2@domain.com")
      #   => true
      def purge_from_cdn(email=nil)
        raise Exception::CDNNotAvailable unless cdn_available?
        headers = {}
        headers = {"X-Purge-Email" => email} if email
        begin
          SoftLayer::Swift::Client.delete_object(self.container.connection.cdnurl, self.container.connection.authtoken, self.container.escaped_name, escaped_name, nil, headers)
          true
        rescue SoftLayer::Swift::ClientException => e
          raise SoftLayer::ObjectStorage::Exception::Connection, "Error Unable to Purge Object: #{@name}" unless (e.status.to_s =~ /^20.$/)
          false
        end
      end

      # A convenience method to stream data into an object from a local file (or anything that can be loaded by Ruby's open method)
      #
      # You can provide an optional hash of headers, in case you want to do something like set the Content-Type manually.
      #
      # Throws an Errno::ENOENT if the file cannot be read.
      #
      #   object.data
      #   => "This is my data"
      #
      #   object.load_from_filename("/tmp/file.txt")
      #   => true
      #
      #
      #   object.data
      #   => "This data was in the file /tmp/file.txt"
      #
      #   object.load_from_filename("/tmp/nonexistent.txt")
      #   => Errno::ENOENT: No such file or directory - /tmp/nonexistent.txt
      def load_from_filename(filename, headers = {}, check_md5 = false)
        f = open(filename)
        if check_md5
            require 'digest/md5'
            md5_hash = Digest::MD5.file(filename)
            headers["Etag"] = md5_hash.to_s()
        end
        self.write(f, headers)
        f.close
        true
      end

      # A convenience method to stream data from an object into a local file
      #
      # Throws an Errno::ENOENT if the file cannot be opened for writing due to a path error,
      # and Errno::EACCES if the file cannot be opened for writing due to permissions.
      #
      #   object.data
      #   => "This is my data"
      #
      #   object.save_to_filename("/tmp/file.txt")
      #   => true
      #
      #   $ cat /tmp/file.txt
      #   "This is my data"
      #
      #   object.save_to_filename("/tmp/owned_by_root.txt")
      #   => Errno::EACCES: Permission denied - /tmp/owned_by_root.txt
      def save_to_filename(filename)
        File.open(filename, 'wb+') do |f|
          self.data_stream do |chunk|
            f.write chunk
          end
        end
        true
      end


      def cdn_urls
        @cdn_urls ||= (
          container.cdn_urls.map {|k,v| v += "/#{escaped_name}"}
        )
      end

      # Get URL for temporary public access.
      #
      def temp_url(min)
        expires = (Time.now.getutc + 60 * min).to_i
        path = "#{container.connection.storagepath}/#{container.name}/#{name}"
        body = "GET\n#{expires}\n#{path}"
        sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'),
                                      container.connection.temp_url_key,
                                      body)
        path = "#{container.connection.storageurl}/#{container.name}/#{name}"
        "#{path}?temp_url_sig=#{sig}&temp_url_expires=#{expires}"
      end
      
      # Copy this object to a new location (optionally in a new container)
      #
      # You must supply either a name for the new object or a container name, or both. If a :name is supplied without a :container, 
      # the object is copied within the current container. If the :container is specified with no :name, then the object is copied
      # to the new container with its current name.
      #
      #    object.copy(:name => "images/funny/lolcat.jpg", :container => "pictures")
      #
      # You may also supply a hash of headers in the :headers option. From there, you can set things like Content-Type, or other
      # headers as available in the API document.
      #
      #    object.copy(:name => 'newfile.tmp', :headers => {'Content-Type' => 'text/plain'})
      #
      # Returns the new SoftLayer::ObjectStorage::StorageObject for the copied item.
      def copy(options = {})
        raise SoftLayer::ObjectStorage::Exception::Syntax, "You must provide the :container, :name, or :headers for this operation" unless (options[:container] || options[:name] || options[:headers])
        new_container = options[:container] || self.container.name
        new_name = options[:name] || self.name
        new_headers = options[:headers] || {}
        raise SoftLayer::ObjectStorage::Exception::Syntax, "The :headers option must be a hash" unless new_headers.is_a?(Hash)
        new_name.sub!(/^\//,'')
        headers = {'X-Copy-From' => "#{self.container.name}/#{self.name}", 'Content-Type' => self.content_type.sub(/;.+/, '')}.merge(new_headers)
        # , 'Content-Type' => self.content_type
        new_path = "#{SoftLayer::ObjectStorage.escape new_container}/#{escape_name new_name}"
        begin
          response = SoftLayer::Swift::Client.put_object(self.container.connection.storageurl, self.container.connection.authtoken, (SoftLayer::ObjectStorage.escape new_container), escape_name(new_name), nil, nil, nil, nil, nil, headers)
          return SoftLayer::ObjectStorage::Container.new(self.container.connection, new_container).object(new_name)
        rescue SoftLayer::Swift::ClientException => e
          code = e.status.to_s
          raise SoftLayer::ObjectStorage::Exception::InvalidResponse, "Invalid response code #{response.code}" unless (response.code =~ /^20/)
        end
      end
      
      # Takes the same options as the copy method, only it does a copy followed by a delete on the original object.
      #
      # Returns the new SoftLayer::ObjectStorage::StorageObject for the moved item. You should not attempt to use the old object after doing
      # a move.
      def move(options = {})
        new_object = self.copy(options)
        self.container.delete_object(self.name)
        self.freeze
        return new_object
      end
        
      def to_s # :nodoc:
        @name
      end

      def escape_name(name)
        SoftLayer::ObjectStorage.escape name
      end

      private

        def make_path(path) # :nodoc:
          if path == "." || path == "/"
            return
          else
            unless self.container.object_exists?(path)
              o = self.container.create_object(path)
              o.write(nil, {'Content-Type' => 'application/directory'})
            end
            make_path(File.dirname(path))
          end
        end

    end

  end
end
