require File.dirname(__FILE__) + '/spec_helper'

describe "SoftLayer Storage" do
  let(:sl_storage){
    SL::Storage::Connection.new(CREDS)
  }
  
  after(:all) do
    sl_storage.containers.each do |c|
      if c =~ /^rspec/
        sl_storage.delete_container(c, true)
      end
    end
  end

  let(:temp_container_name){
    "rspec container - #{Time.now.to_s}"
  }

  let(:temp_object_name){
    "rspec object - #{Time.now.to_s}"
  }

  it "should create and destroy a container" do
    sl_storage.containers.should_not include( temp_container_name)
    container = sl_storage.create_container(temp_container_name)
    sl_storage.containers.should include(temp_container_name)

    sl_storage.delete_container(temp_container_name)
    sl_storage.containers.should_not include(temp_container_name)
  end

  it "should create and destroy an object" do
    container = sl_storage.create_container(temp_container_name)
    temp_object = container.create_object(temp_object_name, false)
    temp_object.write("Test Data - #{temp_object_name}")

    container.objects.should include(temp_object_name)
    container.object(temp_object_name).data.should == "Test Data - #{temp_object_name}"

    container.delete_object(temp_object_name)
    container.objects.should_not include(temp_object_name)
    sl_storage.delete_container(temp_container_name)
  end

  it "should recursively delete containers that contain objects" do
    container = sl_storage.create_container(temp_container_name)
    temp_object = container.create_object(temp_object_name, false)
    temp_object.write("Test Data - #{temp_object_name}")
    
    sl_storage.delete_container(temp_container_name, true)
    sl_storage.containers.should_not include(temp_container_name)
  end

  context "CDN" do
    it "should enable and disable cdn on a container" do
      container = sl_storage.create_container(temp_container_name)
      sl_storage.containers.should include(temp_container_name)
      sl_storage.public_containers.should_not include(temp_container_name)

      container.make_public
      sleep(2)
      sl_storage.public_containers.should include(temp_container_name)

      container.make_private
      sleep(2)
      sl_storage.public_containers.should_not include(temp_container_name)
    end

    it "should set the ttl for a container" do
      ttl = "200"
      container = sl_storage.create_container(temp_container_name)
      container.make_public(ttl)
      container.cdn_metadata['x-cdn-ttl'].should == ttl
    end

    it "should set the ttl for an object" do
      ttl = "400"
      container = sl_storage.create_container(temp_container_name)
      container.make_public()
      
      object = container.create_object(temp_object_name)
      object.write("Test data")
      object.set_ttl(ttl)

      object.cdn_metadata['x-cdn-ttl'].should == ttl
    end

    it "should purge cdn objects" do
      container = sl_storage.create_container(temp_container_name)
      container.make_public
      object = container.create_object(temp_object_name)
      object.write("Test Data")
      object.purge
    end
  end

end
