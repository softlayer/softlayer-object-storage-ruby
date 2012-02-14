# See COPYING for license information.
module SoftLayer
  module ObjectStorage
    class Authentication
      def initialize(connection)
          storage_url, auth_token, headers = SoftLayer::Swift::Client.get_auth(connection.auth_url, connection.authuser, connection.authkey)
        if auth_token 
          parsed_storage_url = URI.parse(headers["x-storage-url"])
          connection.storagehost   = parsed_storage_url.host
          connection.storagepath   = parsed_storage_url.path
          connection.storageport   = parsed_storage_url.port
          connection.storagescheme = parsed_storage_url.scheme
          connection.authtoken     = headers["x-auth-token"]
          connection.authok        = true
        else
          connection.authtoken = false
          raise SoftLayer::ObjectStorage::Exception::Authentication, "Authentication failed"
        end
      end
    end
  end
end
