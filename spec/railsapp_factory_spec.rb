require 'rspec'
require 'spec_helper'
require 'net/http'

require 'railsapp_factory'

describe 'RailsappFactory' do

  # order by number at start of the description and then by random
  # note 'describe' groups always sort after 'it' examples
  RSpec.configure do |config|
    config.order_groups_and_examples do |list|
      list.sort_by { |item| [item.description.sub(/^(\d*).*/, '\1').to_i, rand] }
    end
  end

  before(:all) do
    puts '(before(:all) doing cleanup: rm -rf tmp/railsapp)'
    RailsappFactory.cleanup
  end

  shared_examples_for RailsappFactory do

    it "test should be run with a ruby version manager (OTHERWISE LOTS OF TESTS ARE DISABLED!)" do
      RailsappFactory.has_ruby_version_manager?.should be_true
    end

    describe "Ruby version manager" do
      before do
        @ruby_vs = RailsappFactory.rubies(nil).collect {|s| s.sub(/.*?(\d+\.\d+\.\d+).*/, '\1')}
      end

      it 'must have ruby 1.8.7' do
        @ruby_vs.should include('1.8.7')
      end

      it 'must have ruby 1.9.3' do
        @ruby_vs.should include('1.9.3')
      end

    end

    unless RailsappFactory.has_ruby_version_manager?
      it 'should suggest rubies that can be used with this rails version' do
        list = @factory.rubies
        list.should be_a_kind_of(Array)
        list.should_not be_empty
      end

    end

    it '#use should set using' do
      fake_version = '3.14.159'
      @factory.using.should == ''
      @factory.use(fake_version)
      @factory.using.should == fake_version
      @factory.use(nil)
      @factory.using.should == ''
    end

    it '#use should accept a block and only set using within it' do
      fake_version = '3.14.159'
      @factory.using.should == ''
      ran_block = false
      @factory.use(fake_version) do
        @factory.using.should == fake_version
        ran_block = true
      end
      ran_block.should == true
      @factory.using.should == ''
    end

    it 'new should not build the application' do
      @factory.should_not be_built
    end

    it 'should pick an appropriate version' do
      if @factory.version =~ /2.3-lts/
        @factory.release.should == '2.3.18'
      else
        @factory.release.should match(/^#{@factory.version}\./)
      end
    end

    it '1: should allow a file to be used as a template' do
      @factory.use_template('spec/templates/add-file.rb')
    end

    it '1: should allow a url to be used as a template' do
      @factory.use_template('https://raw2.github.com/ianheggie/railsapp_factory/master/spec/templates/add-another-file.rb')
    end

    it '1: should allow text to be appended to template' do
      @factory.append_to_template("file 'public/file.txt', 'some text'")
    end

    describe '2: when built using #build' do
      include SpecHelper

      before(:all) do
        @factory.build
      end

      it '#built? should be true' do
        @factory.should be_built
      end

      it 'a rails app should have been installed at root' do
        Dir.chdir(@factory.root) do
          Kernel.system 'find . -print | sort'
          expected = %w{ app config db lib log public test tmp }
          have = expected.select { |d| File.directory?(d) }
          have.should == expected
          expected = %w{app/controllers/application_controller.rb
                        config/database.yml config/environment.rb config/routes.rb  }
          have = expected.select { |fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it 'it should have gems installed by bundler' do
        Dir.chdir(@factory.root) do
          expected = %w{ Gemfile Gemfile.lock }
          have = expected.select { |fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it 'the file template should have been processed' do
        file = File.join(@factory.root, 'file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it 'the url template should have been processed' do
        file = File.join(@factory.root, 'another-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it 'the text appended to the template should have been processed' do
        file = File.join(@factory.root, 'public/file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /some text/
      end

      it 'shell_eval should return stdout' do
        @factory.shell_eval('date').should =~ /\d\d:\d\d/
        @factory.shell_eval('env').should =~ /PATH=/
      end

      it 'RAILS_ENV should be set to test' do
        @factory.env.should be_test
        @factory.env.to_s.should == 'test'
        @factory.shell_eval('echo $RAILS_ENV').should == "test\n"
        @factory.shell_eval('echo $RACK_ENV').should == "test\n"
      end

      it 'ruby_eval should handle simple values' do
        @factory.ruby_eval('1 + 2').should == 3
        @factory.ruby_eval("'a-' + \"string\"").should == 'a-string'
        @factory.ruby_eval('[1, :pear]').should == [1, 'pear']
        @factory.ruby_eval("{ 'apple' => 23 }").should == {'apple' => 23}
      end

      it 'rails_eval should report rails specific values' do
        @factory.rails_eval('Rails.env').should == @factory.env.to_s
      end

      if RUBY_VERSION !~ /^1\.8/
        # ruby_eval uses runner for ruby 1.8.7
        it 'ruby_eval should not report rails specific values' do
          lambda { @factory.ruby_eval('Rails.env') }.should raise_error(NameError)
        end
      end

      it 'ruby_eval should try and reproduce exceptions thrown' do
        lambda { @factory.ruby_eval('1 / 0') }.should raise_error(ZeroDivisionError)
      end

      it 'ruby_eval should handle require and multi line commands' do
        @factory.ruby_eval("before = 123\nrequire 'cgi'\nafter = defined?(CGI)\n[before,after]").should == [123, 'constant']
      end

      it 'ruby_eval should throw argument error on syntax errors' do
        lambda { @factory.ruby_eval('def missing_an_arg(=2); end') }.should raise_error(ArgumentError)
      end

      it 'ruby_eval allows choice of :yaml' do
        @factory.ruby_eval('Set.new([1,2])', :yaml).should == Set.new([1, 2])
      end

      it 'ruby_eval by default uses :json which converts non simple objects to either their class name or a simple object' do
        ret = @factory.ruby_eval('Set.new([1,2])', :json)
        if ret.is_a? Array
          ret.should == [1, 2]
        else
          ret.should be_kind_of(String)
          ret.should match(/#<Set:0x\w+>/)
        end
      end

      it 'override_ENV should allow arbitrary environment variables to be set' do
        @factory.override_ENV['ARBITRARY_VAR'] = 'some value'
        @factory.in_app do
          ENV['ARBITRARY_VAR']
        end.should == 'some value'
        @factory.shell_eval('echo $ARBITRARY_VAR').should == "some value\n"
        @factory.ruby_eval("ENV['ARBITRARY_VAR']").should == 'some value'
        ENV['ARBITRARY_VAR'].should == nil
      end

      unless RailsappFactory.has_ruby_version_manager?

        it 'ruby_eval should work with all the rubies' do
          RUBY_VERSION.should == @factory.ruby_eval('RUBY_VERSION')
          @factory.rubies.each do |ruby_v|
            @factory.use(ruby_v) do
              actual_ruby_v = @factory.ruby_eval('RUBY_VERSION')
              actual_version_should_match_rubies_version(actual_ruby_v, ruby_v, false)
            end
          end
        end

        it 'rails_eval should work with all the rubies' do
          begin
            RUBY_VERSION.should == @factory.ruby_eval('RUBY_VERSION')
            @factory.rubies.each do |ruby_v|
              @factory.use(ruby_v)
              actual_ruby_v = @factory.rails_eval('RUBY_VERSION')
              actual_version_should_match_rubies_version(actual_ruby_v, ruby_v, false)
            end
          ensure
            # and nil should return to default
            @factory.use(nil)
            RUBY_VERSION.should == @factory.ruby_eval('RUBY_VERSION')
          end
        end

        it 'shell_eval should work with all the rubies' do
          RUBY_VERSION.should == @factory.ruby_eval('RUBY_VERSION')
          @factory.rubies.each do |ruby_v|
            @factory.use(ruby_v) do
              actual_ruby_v = @factory.shell_eval('ruby -v')
              actual_version_should_match_rubies_version(actual_ruby_v, ruby_v)
            end
          end
        end

        it 'system_in_app should work with all the rubies' do
          RUBY_VERSION.should == @factory.ruby_eval('RUBY_VERSION')
          @factory.rubies.each do |ruby_v|
            @factory.use(ruby_v) do
              tmp_filename = Tempfile.new('ruby_version').path
              @factory.system_in_app("ruby -v > #{tmp_filename}")
              actual_ruby_v = File.read(tmp_filename)
              actual_version_should_match_rubies_version(actual_ruby_v, ruby_v)
              FileUtils.rm_f tmp_filename
            end
          end
        end
      end

      it 'should allow appended templates to be processed after build' do
        @factory.append_to_template("file '4th-file.txt', 'more text'")
        @factory.process_template
        file = File.join(@factory.root, '4th-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /more text/
      end

      it 'should allow template files to be processed after build' do
        @factory.use_template('spec/templates/add-yet-another-file.rb')
        @factory.process_template
        file = File.join(@factory.root, 'yet-another-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /a short poem/
      end

      describe 'when server is run using #start', :order => :partially_ordered do
        before(:all) do
          @factory.start.should be_true
        end

        after(:all) do
          @factory.stop
        end

        it 'start should run the application' do
          @factory.should be_alive
        end

        it 'the application should be on a non privileged port' do
          @factory.port.should > 1024
        end

        it 'should have a http server running on port' do
          response = Net::HTTP.get(URI(@factory.url))
          response.should be_an_instance_of(String)
        end

        it 'should serve status files' do
          response = Net::HTTP.get(@factory.uri('file.txt'))
          response.should be_an_instance_of(String)
        end

        it 'should respond with an error for missing paths' do
          response = Net::HTTP.get_response(@factory.uri('/no_such_path'))
          %w{404 500}.should include(response.code)
          response.body.should =~ /No route matches/
        end

        it '9: stop should stop the application' do
          @factory.stop.should be_true
          @factory.should_not be_alive
        end
      end

      unless RailsappFactory.has_ruby_version_manager?

        it 'the server should work with all the ruby versions' do
          @factory.rubies.each do |ruby_v|
            @factory.use(ruby_v) do
              begin
                @factory.start
                actual_ruby_v = Net::HTTP.get(@factory.uri('/ruby_version'))
              ensure
                @factory.stop
              end
              actual_version_should_match_rubies_version(actual_ruby_v, ruby_v, false)
            end
          end
        end
      end

    end

    describe '9: at the end' do
      it 'the server log file should have contents' do
        @factory.system_in_app 'du'
        @factory.system_in_app 'ls -laR log'
        File.size(File.join(@factory.root, "log/#{@factory.env}.log")).should > 0
      end

      it '9: destroy should remove the root directory' do
        root = @factory.root
        @factory.destroy
        File.directory?(root).should be_false if root
      end
    end

  end

  # latest compatible rails version
  context '::new (latest compatible version)' do
    before(:all) do
      @factory = RailsappFactory.new()
    end
    after(:all) do
      @factory.destroy
    end

    it_behaves_like RailsappFactory
  end

  RailsappFactory.versions.each do |ver|
    before(:all) do
      @factory = RailsappFactory.new(ver)
    end
    after(:all) do
      @factory.destroy
    end

    next if ver == RailsappFactory.versions.last # don't retest last version

    context "::new(#{ver})" do

      it_behaves_like RailsappFactory

    end
    #break unless ENV['TRAVIS'] == 'true'
  end

end