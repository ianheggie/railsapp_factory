require 'rspec'
require 'net/http'

require 'railsapp_factory'

describe 'RailsappFactory' do

  before(:all) do
    puts "(DESTROYING ALL)"
    RailsappFactory.cleanup
  end

  describe '::versions' do

    it 'should list some rails versions' do
      puts "RUBY_VERSION = #{RUBY_VERSION}"
      list = RailsappFactory.versions
      list.should be_a_kind_of(Array)
      list.should_not be_empty
    end

    it 'should return an empty list for unknown ruby versions' do
      list = RailsappFactory.versions('1.5.0')
      list.should be_a_kind_of(Array)
      list.should be_empty
    end

    # taken from http://www.devalot.com/articles/2012/03/ror-compatibility
    {
        '1.8.6' => %w{2.3},
        '1.8.7' => %w{2.3 3.0 3.1 3.2},
        '1.9.1' => %w{2.3},
        '1.9.2' => %w{3.0 3.1 3.2},
        '1.9.3' => %w{3.0 3.1 3.2 4.0},
        '2.0.x' => %w{4.0}
    }.each do |ruby_v, expected|
      it "should list rails versions that are compatible with ruby #{ruby_v}" do
        list = RailsappFactory.versions(ruby_v)
        list.should be_a_kind_of(Array)
        list.should_not be_empty
        list.should == expected
      end
    end

  end

  describe "::encode_query" do

    it "should encode a simple argument" do
      RailsappFactory.encode_query(:ian => 23).should == "?ian=23"
    end

    it "should encode a nested argument" do
      RailsappFactory.encode_query(:author => {:ian => 23}).should == '?author%5Bian%5D=23'
    end

    it "should encode a multiple arguments" do
      res = RailsappFactory.encode_query(:ian => 23, :john => '45')
      #order not guaranteed
      if res =~ /^.ian/
        res.should == '?ian=23&john=45'
      else
        res.should == '?john=45&ian=23'
      end
    end

  end

  RailsappFactory.versions.each do |ver|

    context "new(#{ver})" do
      # ordered tests
      RSpec.configure do |config|
        config.order_groups_and_examples do |list|
          list.sort_by { |item| item.description }
        end
      end

      before(:all) do
        @factory = RailsappFactory.new(ver)
      end

      it "05: new should not build the application" do
        @factory.should_not be_built
      end

      it '10: should pick an appropriate version' do
        @factory.release.should match(/^#{ver}\./)
      end

      it "15: should allow a file to be used as a template" do
        @factory.use_template(File.expand_path('templates/add-file.rb', File.dirname(__FILE__)))
      end

      it "15: should allow a url to be used as a template" do
        @factory.use_template(File.expand_path('templates/add-another-file.rb', File.dirname(__FILE__)))
      end

      it "15: should allow text to be appended to template" do
        @factory.append_to_template("file 'public/file.txt', 'some text'")
      end

      it '20: build should should build the application' do
        @factory.build
        @factory.should be_built
      end

      it '25: a rails app should have been installed at root' do
        Dir.chdir(@factory.root) do
          Kernel.system "find . -print | sort"
          expected = %w{ app config db lib log public test tmp }
          have = expected.select {|d| File.directory?(d) }
          have.should == expected
          expected = %w{app/controllers/application_controller.rb
                      config/database.yml config/environment.rb config/routes.rb  }
          have = expected.select {|fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it '25: it should have gems installed by bundler' do
        Dir.chdir(@factory.root) do
          expected = %w{ Gemfile Gemfile.lock }
          have = expected.select {|fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it "25: the file template should have been processed" do
        file = File.join(@factory.root, 'file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it "25: the url template should have been processed" do
        file = File.join(@factory.root, 'another-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it "25: the text appended to the template should have been processed" do
        file = File.join(@factory.root, 'public/file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /some text/
      end

      it '25: shell_eval should return stdout' do
        @factory.shell_eval("date").should =~ /\d\d:\d\d/
        @factory.shell_eval("env").should =~ /PATH=/
      end

      it '25: RAILS_ENV should be set to test' do
        @factory.env.should be_test
        @factory.env.to_s.should == 'test'
        @factory.shell_eval("echo $RAILS_ENV").should == "test\n"
        @factory.shell_eval("echo $RACK_ENV").should == "test\n"
      end

      it '25: ruby_eval should handle simple values' do
        @factory.ruby_eval("1 + 2").should == 3
        @factory.ruby_eval("'a-' + \"string\"" ).should == 'a-string'
        @factory.ruby_eval("[1, :pear]" ).should == [1, 'pear']
        @factory.ruby_eval("{ 'apple' => 23 }").should == { 'apple' => 23 }
      end

      it '25: rails_eval should report rails specific values' do
        @factory.rails_eval("Rails.env").should == @factory.env.to_s
      end

      if RUBY_VERSION !~ /^1\.8/
        # ruby_eval uses runner for ruby 1.8.7
        it '25: ruby_eval should not report rails specific values' do
          lambda { @factory.ruby_eval("Rails.env") }.should raise_error(NameError)
        end
      end

      it '25: ruby_eval should try and reproduce exceptions thrown' do
        lambda { @factory.ruby_eval("1 / 0") }.should raise_error(ZeroDivisionError)
      end

      it '25: ruby_eval should handle require and multi line commands' do
        @factory.ruby_eval("before = 123\nrequire 'cgi'\nafter = defined?(CGI)\n[before,after]").should == [123, 'constant']
      end

      it '25: ruby_eval should throw argumenterror on syntax errors' do
        lambda { @factory.ruby_eval('def missing_an_arg(=2); end') }.should raise_error(ArgumentError)
      end

      it '25: ruby_eval allows choice of :yaml' do
        @factory.ruby_eval("Set.new([1,2])", :yaml).should == Set.new([1,2])
      end

      it '25: ruby_eval by default uses :json which converst objects to simple types' do
        @factory.ruby_eval("Set.new([1,2])", :json).should == [1,2]
      end

      it '25: factory.env should allow arbitrary environment variables to be set' do
        @factory.override_ENV['ARBITRARY_VAR'] = 'some value'
        @factory.in_app do
          ENV['ARBITRARY_VAR']
        end.should == 'some value'
        @factory.shell_eval("echo $ARBITRARY_VAR").should == "some value\n"
        @factory.ruby_eval("ENV['ARBITRARY_VAR']").should == "some value"
        ENV['ARBITRARY_VAR'].should == nil
      end

      it "30: should allow templates to be processed after build" do
        @factory.append_to_template("file '4th-file.txt', 'more text'")
        @factory.process_template
        file = File.join(@factory.root, '4th-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /more text/
      end

      it '40: start should run the application' do
        @factory.start.should be_true
        @factory.should be_alive
      end

      it '45: the application should be on a non privileged port' do
        @factory.port.should > 1024
      end

      it '45: should have a http server running on port' do
        response = Net::HTTP.get(URI(@factory.url))
        response.should be_an_instance_of(String)
      end

      it '45: should serve status files' do
        response = Net::HTTP.get(@factory.uri('file.txt'))
        response.should be_an_instance_of(String)
      end

      it '45: should respond with an error for missing paths' do
        response = Net::HTTP.get_response(@factory.uri('/no_such_path'))
        %w{404 500}.should include(response.code)
        response.body.should =~ /No route matches/
      end

      it '95: the server log file should have contents' do
        @factory.system_in_app "du ; ls -laR log"
        File.size(File.join(@factory.root, "log/#{@factory.env}.log")).should > 0
      end

      it '99: destroy should remove the root directory' do
        root = @factory.root
        @factory.destroy
        File.directory?(root).should be_false if root
      end

    end

    break unless ENV['TRAVIS'] == 'true'

  end


end