# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "softlayer/object_storage/version"

Gem::Specification.new do |s|
  s.name        = "softlayer-object-storage"
  s.version     = SoftLayer::ObjectStorage::VERSION
  s.authors     = ["Tim Ariyeh"]
  s.email       = ["tariyeh@softlayer.com"]
  s.homepage    = ""
  s.summary     = %q{Ruby language bindings for SoftLayer Object Storage}
  s.description = %q{Ruby language bindings for SoftLayer Object Storage}

  s.rubyforge_project = "softlayer-object-storage"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
end
