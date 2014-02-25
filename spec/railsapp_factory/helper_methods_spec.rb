require 'rspec'

require 'railsapp_factory/class_methods'
require 'railsapp_factory/helper_methods'

describe 'RailsappFactory::ClassMethods' do

  class SubjectClass
    extend RailsappFactory::ClassMethods
    include RailsappFactory::HelperMethods

    # from server_methods
    attr_accessor :port, :pid

    # from RunInAppMethods
    attr_accessor :using

  end

  subject { SubjectClass.new }

  describe "#uri" do
    before do
      subject.port = 123
    end

    it "should return a URI" do
      subject.uri('/a/path').should be_a_kind_of(URI)
    end
    it "should be for 127.0.0.1" do
      subject.uri('/a/path').to_s.should start_with('http://127.0.0.1:123/')
    end
    it "should end in given path" do
      subject.uri('/a/path').to_s.should end_with('/a/path')
    end

  end

  describe "#url" do
    before do
      subject.port = 567
    end


    it "should return a URI" do
      subject.url('/a/path').should be_a_kind_of(String)
    end
    it "should be for 127.0.0.1" do
      subject.url('/a/path').should start_with('http://127.0.0.1:567/')
    end
    it "should end in given path" do
      subject.url('/a/path').should end_with('/a/path')
    end

  end


  describe "#env=" do
    before do
      subject.env = 'development'
    end

    it "should set @override_ENV RAILS_ENV/RACK_ENV" do
      subject.override_ENV['RAILS_ENV'].should == 'development'
      subject.override_ENV['RACK_ENV'].should == 'development'
    end

    it "should be reflected in env" do
      subject.env.test?.should be_false
      subject.env.should be_development
    end

  end

  describe "#env" do
    it "should be test by default" do
      subject.env.to_s.should == 'test'
      subject.env.should be_test
      subject.env.should_not be_development
    end
  end

  describe "#rubies" do

    it "should return a list of rubies" do
      list = subject.rubies(nil)
      list.should be_a_kind_of(Array)
      list.should_not be_empty
    end
  end

  describe "#alive?" do

    it "should report an alive process as alive" do
      IO.popen('cat', 'w') do |pipe|
        subject.pid = pipe.pid
        subject.should be_alive
      end
    end

    it "should report a completed process as dead" do
      IO.popen('cat', 'w') do |pipe|
        subject.pid = pipe.pid
      end
      subject.should_not be_alive
    end

    it "should report nil pid as dead" do
      subject.pid = nil
      subject.should_not be_alive
    end

  end

  describe "logger" do
    it "has valid logger" do
      subject.logger.should respond_to(:info, :warn, :debug, :error)
    end
  end


end


