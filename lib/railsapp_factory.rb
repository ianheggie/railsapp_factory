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
  attr_reader :override_ENV
  attr_accessor :gem_source, :db, :timeout, :logger

  def initialize(version, logger = Logger.new(STDERR))
    @version = version
    @logger = logger
    throw ArgumentError.new('Invalid version') if version !~ /^[2-9](\.\d+){1,2}(-lts)?$/
    @logger.info("RailsappFactory initialized with version #{version}")
    @gem_source = 'https://rubygems.org'
    @db = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
    @timeout = 300 # 5 minutes
    @override_ENV = {}
    self.env = 'test'
    clear_template
  end

end
