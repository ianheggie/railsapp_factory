require 'tmpdir'
require 'bundler'
require 'fileutils'
require 'logger'
require 'open-uri'

require 'railsapp_factory/class_methods'

require 'railsapp_factory/build_methods'
require 'railsapp_factory/helper_methods'
require 'railsapp_factory/run_in_app_methods'
require 'railsapp_factory/server_methods'
require 'railsapp_factory/string_inquirer'
require 'railsapp_factory/template_methods'

require 'railsapp_factory/build_error'

require 'railsapp_factory/version'

class RailsappFactory

  extend RailsappFactory::ClassMethods
  include RailsappFactory::BuildMethods
  include RailsappFactory::HelperMethods
  include RailsappFactory::RunInAppMethods
  include RailsappFactory::ServerMethods
  include RailsappFactory::TemplateMethods

  TMPDIR = File.expand_path('tmp/railsapps')

  attr_reader :version # version requested, may be specific release, or the first part of a release number
  attr_accessor :gem_source, :db, :timeout, :logger

  def initialize(version = nil, logger = Logger.new(STDERR))
    self.logger = logger
    @version = version
    unless @version
      @version = RailsappFactory.versions(RUBY_VERSION).last
    end
    self.logger.info("RailsappFactory.new(#{version.inspect}) called - version set to #{@version}")
    raise ArgumentError.new("Invalid version (#{@version})") if @version.to_s !~ /^[2-9](\.\d+){1,2}(-lts)?$/
    @gem_source = 'https://rubygems.org'
    @db = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
    @timeout = 300 # 5 minutes
    clear_template
    # use default ruby
    use(nil)
  end

end
