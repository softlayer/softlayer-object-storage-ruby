# See COPYING for license information.
require "softlayer/object_storage/version"
require "softlayer/object_storage/connection"
require "softlayer/object_storage/authentication"
require "softlayer/object_storage/exception"
require "softlayer/object_storage/container"
require "softlayer/object_storage/storage_object"

require "cgi"

require File.join(File.dirname(__FILE__), "/../client")

module SoftLayer
  module ObjectStorage

    ENDPOINTS = {
      :dal05 => {
        :public => {
          :http => "http://dal05.objectstorage.softlayer.net/auth/v1.0",
          :https => "https://dal05.objectstorage.softlayer.net/auth/v1.0"
        },
        :private => {
          :http => "http://dal05.objectstorage.service.networklayer.com/auth/v1.0",
          :https => "https://dal05.objectstorage.service.networklayer.com/auth/v1.0"
        }
      }
    }

    def self.escape(str)
      URI.escape(str,  Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end
  end
end
