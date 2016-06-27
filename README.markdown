SoftLayer Object Storage Ruby Client
====================================

Ruby bindings for SoftLayer Object Storage

Installation from Source
------------------------

```
git clone https://github.com/softlayer/softlayer-object-storage-ruby.git
cd softlayer-object-storage
gem build softlayer-object-storage.gemspec 
gem install softlayer-object-storage 
```

Basic Usage
----------

```ruby
require 'softlayer/object_storage'
sl_storage = SoftLayer::ObjectStorage::Connection.new({
    :username => "YOUR_USERNAME", 
    :api_key => "YOUR_API_KEY", 
    :datacenter => :dal05
})

sl_storage.containers
# ["foo"]

sl_storage.create_container("bar")

sl_storage.containers
# ["foo", "bar"]

container = sl_storage.container("foo")
container.objects
# []

container.create_object("baz")

container.objects
# ["foo"]

object = container.object("foo")
```

Search Usage
-----------

```ruby
results = sl_storage.search(:q => "bar")

puts results[:count]
# 1

puts results[:items][0].inspect
# {:type => "container", :name => "bar"...}
```

For complete usage examples, see the specs.

Temporary Public Access
-----------------------

To get temporary url with 30 minutes expiration from now,

```ruby
puts object.temp_url(30)
```

