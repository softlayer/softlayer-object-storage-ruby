# See COPYING for license information.
# The deprecated old exception types.  Will go away in a couple of releases.

class SyntaxException             < StandardError # :nodoc:
end
class ConnectionException         < StandardError # :nodoc:
end
class AuthenticationException     < StandardError # :nodoc:
end
class InvalidResponseException    < StandardError # :nodoc:
end
class NonEmptyContainerException  < StandardError # :nodoc:
end
class NoSuchObjectException       < StandardError # :nodoc:
end
class NoSuchContainerException    < StandardError # :nodoc:
end
class NoSuchAccountException      < StandardError # :nodoc:
end
class MisMatchedChecksumException < StandardError # :nodoc:
end
class IOException                 < StandardError # :nodoc:
end
class CDNNotEnabledException      < StandardError # :nodoc:
end
class ObjectExistsException       < StandardError # :nodoc:
end
class ExpiredAuthTokenException   < StandardError # :nodoc:
end

# The new properly scoped exceptions.

module SoftLayer
  module ObjectStorage
    module Exception

      class Syntax             < SyntaxException
      end
      class Connection         < ConnectionException # :nodoc:
      end
      class Authentication     < AuthenticationException # :nodoc:
      end
      class InvalidResponse    < InvalidResponseException # :nodoc:
      end
      class NonEmptyContainer  < NonEmptyContainerException # :nodoc:
      end
      class NoSuchObject       < NoSuchObjectException # :nodoc:
      end
      class NoSuchContainer    < NoSuchContainerException # :nodoc:
      end
      class NoSuchAccount      < NoSuchAccountException # :nodoc:
      end
      class MisMatchedChecksum < MisMatchedChecksumException # :nodoc:
      end
      class IO                 < IOException # :nodoc:
      end
      class CDNNotEnabled      < CDNNotEnabledException # :nodoc:
      end
      class ObjectExists       < ObjectExistsException # :nodoc:
      end
      class ExpiredAuthToken   < ExpiredAuthTokenException # :nodoc:
      end
      class CDNNotAvailable    < StandardError
      end
      
    end
  end
end
