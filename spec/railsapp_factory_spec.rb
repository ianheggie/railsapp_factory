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
        '1.8.6' => %w{2.3 },
        '1.8.7' => %w{2.3 3.0 3.1 3.2},
        '1.9.1' => %w{2.3 },
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

      it "10: new should not build the application" do
        @factory.should_not be_built
      end

      it '20: should pick an appropriate version' do
        @factory.release.should match(/^#{ver}\./)
      end

      it "21: should allow a file to be used as a template" do
        @factory.use_template(File.expand_path('templates/add-file.rb', File.dirname(__FILE__)))
      end

      it "21: should allow a url to be used as a template" do
        @factory.use_template(File.expand_path('templates/add-another-file.rb', File.dirname(__FILE__)))
      end

      it "21: should allow text to be appended to template" do
        @factory.append_to_template("file '3rd-file.txt', 'some text'")
      end

      it '30: build should should build the application' do
        @factory.build
        @factory.should be_built
      end

      it '40: a rails app should be installed at root' do
        Dir.chdir(@factory.root) do
          system "find . -print | sort"
          expected = %w{ app config db lib log public test tmp }
          have = expected.select {|d| File.directory?(d) }
          have.should == expected
          expected = %w{app/controllers/application_controller.rb
                      config/database.yml config/environment.rb config/routes.rb  }
          have = expected.select {|fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it '40: it should have gems installed by bundler' do
        Dir.chdir(@factory.root) do
          expected = %w{ Gemfile Gemfile.lock }
          have = expected.select {|fn| File.exists?(fn) }
          have.should == expected
        end
      end

      it "40: the file template should have been processed" do
        file = File.join(@factory.root, 'file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it "40: the url template should have been processed" do
        file = File.join(@factory.root, 'another-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /Lorem ipsum/
      end

      it "40: the text appended to the template should have been processed" do
        file = File.join(@factory.root, '3rd-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /some text/
      end

      it "40: should allow templates to be processed after build" do
        @factory.append_to_template("file '4th-file.txt', 'more text'")
        @factory.process_template
        file = File.join(@factory.root, '4th-file.txt')
        File.exists?(file).should be_true
        File.open(file).read.should =~ /more text/
      end

      it '50: start should run the application' do
        @factory.start.should be_true
        @factory.should be_running
        @factory.port.should > 1024
      end

      it '60: the application should be on a non privledged port' do
        @factory.port.should > 1024
      end

      it '60: the log file should have contents' do
        File.size(File.join(@factory.root, 'log/development.log')).should > 0
      end

      it '60: should have a http server running on port' do
        response = Net::HTTP.get(URI(@factory.url))
        response.should be_an_instance_of(String)
      end

      it '99: destroy should remove the root directory' do
        root = @factory.root
        @factory.destroy
        File.directory?(root).should be_false if root
      end

    end

    break unless ENV['TRAVIS_CI']

  end


end