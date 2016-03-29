require File.dirname(__FILE__) + '/spec_helper'

RSpec.describe SoftLayer::ObjectStorage do
  let(:conn) {
    SoftLayer::ObjectStorage::Connection.new(CREDS)
  }

  it "should generate TempURL for first object" do
    r = conn.search()
    expect(r[:count]).not_to eq(0)

    i = r[:items][0]
    cont = conn.container(i["container"])
    obj = cont.object(i["name"])
    expect(system("wget -q \"#{obj.temp_url(30)}\" -O /dev/null")).to eq(true)
  end

  it "should generate TempURL for first object without get Object" do
    r = conn.search()
    expect(r[:count]).not_to eq(0)

    i = r[:items][0]
    cont = conn.container(i["container"])
    turl = cont.object_temp_url(i["name"], 30)
    expect(system("wget -q \"#{turl}\" -O /dev/null")).to eq(true)
  end
end
