# See COPYING for license information.
require "sl-storage/version"
require "sl-storage/connection"
require "sl-storage/authentication"
require "sl-storage/exception"
require "sl-storage/container"
require "sl-storage/storage_object"

require "cgi"

require File.join(File.dirname(__FILE__), "client")

module SL
  module Storage
    def self.escape(str)
      URI.escape(str,  Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end
  end
end
