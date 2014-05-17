require 'bundler'
require 'logger'

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

  def initialize(version = nil, logger = Logger.new(STDERR))
    self.logger = logger
    @version = version
    unless @version
      @version = RailsappFactory.versions(RUBY_VERSION).last || '4.1'
    end
    self.logger.info("RailsappFactory.new(#{version.inspect}) called - version set to #{@version}")
    raise ArgumentError.new("Invalid version (#{@version})") if @version.to_s !~ /^[2-9](\.\d+){1,2}(-lts)?$/
    self.gem_source = 'https://rubygems.org'
    self.db = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
    # 5 minutes
    self.timeout = 300
    # clears build vars
    destroy
    # clear template vars
    clear_template
    # use default ruby
    use(nil)
  end

end
