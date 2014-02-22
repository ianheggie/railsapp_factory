require 'railsapp_factory/version'
require 'tmpdir'
require 'bundler'
require 'fileutils'
require 'tempfile'
require 'logger'

class RailsappFactory

  class BuildError < RuntimeError

  end

  BASE_PATH = './tmp/railsapps'

  attr_reader :version      # version requested, may be specific release, or the first part of a release number
  attr_reader :root         # root dir of application
  attr_reader :pid, :running
  attr_reader :port, :url
  attr_reader :server_logfile
  attr_accessor :gem_source, :db, :timeout, :logger

  def initialize(version)
    @version = version
    throw ArgumentError.new('Invalid version') if version !~ /^[2-9](\.\d+){1,2}$/
    @gem_source = 'https://rubygems.org'
    @db = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
    @timeout = 300 # 5 minutes
    @logger = Logger.new(STDERR)
  end

  def self.versions(ruby_v = RUBY_VERSION)
    case (ruby_v.to_s)
      when /^1\.8\.6/
        %w{2.3 }
      when /^1\.8\.7/
        %w{2.3 3.0 3.1 3.2}
      when /^1\.9\.1/
        %w{2.3 }
      when /^1\.9\.2/
        %w{3.0 3.1 3.2}
      when /^1\.9\.3/
        %w{3.0 3.1 3.2 4.0}
      when /^2\.0/
        %w{4.0}
      else
        []
    end
  end

  # release installed as reported by the rails command itself
  def release
    @release ||= begin
      cmd = rails_command
      @logger.debug "Getting release using command: #{cmd}"
      r = in_app(BASE_PATH) { `#{cmd} '-v'` }.sub(/^Rails */, '')
      @logger.debug "Release: #{r}"
      r
    end
  end

  def built?
    @built
  end


  def in_app(in_directory = @root)
    Bundler.with_clean_env do
      Dir.chdir(in_directory) do
        if @timeout > 0
          Timeout.timeout(@timeout) do
            yield
          end
        else
          yield
        end
      end
    end
  end


  def build
    destroy if @base_dir
    @built = false
    FileUtils.mkdir_p BASE_PATH
    @base_dir = Dir.mktmpdir("app-#{@version}", BASE_PATH)
    @root = File.join(@base_dir, 'railsapp')
    new_arg = version =~ /^[12]/ ? '' : ' new'
    other_args = version =~ /^[12]/ ? '' : '--no-rc --skip-bundle' #  '   # --template=TEMPLATE
    other_args <<= ' --edge' if @version == 'edge'

    @logger.info "Creating Rails #{@version} app"
    unless in_app(@base_dir) { system "sh -xc 'time #{rails_command} #{new_arg} railsapp -d #{db} #{other_args}' #{@logger.debug? ? '' : ' >> rails_new.log 2>&1'}" }
      raise BuildError.new("rails #{new_arg}railsapp failed - see rails_new.log")
    end
    raise BuildError.new("error building railsapp - missing files") unless File.exists?(File.join(@root, 'config', 'application.rb'))
    @logger.info "Installing gems using bundle"
    unless in_app { system "sh -xc 'time bundle install --binstubs .bundle/bin' #{@logger.debug? ? '' : ' >> bundle.log 2>&1'}"}
        raise BuildError.new("bundle install --binstubs #{@logger.debug? ? '' : '- see bundle.log'}")
    end
    raise BuildError.new("error installing gems #{@logger.debug? ? '' : '- see bundle.log'}") unless File.exists?(File.join(@root, 'Gemfile.lock'))
    @built = true
  end

  def alive?
    if @pid
      begin
        Process.kill(0, @pid)
        @logger.debug "Process #{@pid} is alive"
        true
      rescue Errno::EPERM
        true # changed uid
      rescue Errno::ESRCH
        @logger.debug "Process #{@pid} not found"
        false # NOT running
      rescue
        nil # Unable to determine status
      end
    end
  end

  def running?
    @running
  end

  def start
    build unless built?
    # find random unassigned port
    server = TCPServer.new('127.0.0.1', 0)
    @port = server.addr[1]
    server.close
    @url = "http://127.0.0.1:#{port}/"
    file = Tempfile.new("#{@base_dir}/server_log")
    @server_logfile = file.path
    file.close
    @logger.info "Running Rails #{version} server on port #{port}" # with output to #{@server_logfile})"
    in_app { @server_handle = IO.popen("exec /bin/sh -xc 'exec #{server_command} -p #{port}' #{@logger.debug? ? '' : " >> #{@server_logfile} 2>&1"}", 'w') }
    @pid = @server_handle.pid
    t1 = Time.new
    while true
      raise TimeoutError.new("Waiting for server to be available on the port - see #{@server_logfile}") if t1 + @timeout < Time.new
      raise BuildError.new("Error starting server - see #{@server_logfile}") unless alive?
      sleep(0.5)
      response = Net::HTTP.get(URI(@url)) rescue nil
      if response
        t2 = Time.new
        @logger.info "Server responded to http GET after %3.1f seconds" % (t2 - t1)
        @running = true
        break
      end
    end
    @running
  end

  def pid
    @server_handle && @server_handle.pid rescue nil
  end

  def stop
    if alive?
      if @pid
        @logger.info "Stopping server (pid #{pid})"
        system "ps -fp #{@pid}" if @logger.debug?
        Process.kill('INT', @pid) rescue nil
        20.times do
          sleep(0.5)
          break unless alive?
        end
        if alive?
          @logger.info "Gave up waiting (terminating process #{pid} with extreme prejudice)"
          Process.kill('KILL', @pid) rescue nil
        end
      end
      @logger.debug "Closing pipe to server process"
      Timeout.timeout(@timeout) do
        @server_handle.close
      end
      @server_handle = nil
    end
    @logger.info "Server has stopped"
    @running = false
  end

  def destroy
    stop
    if @base_dir
      FileUtils.rm_rf "#{BASE_PATH}.last.#{@version}"
      FileUtils.mv @base_dir, "#{BASE_PATH}.last.#{@version}" if File.directory?(@base_dir)
      FileUtils.rm_rf @base_dir
    end
    @base_dir = nil
    @built = false
  end

  def self.cleanup
    FileUtils.rm_rf BASE_PATH
  end

  private

  def version_spec
    @version == 'edge' ? "github: 'rails/rails'" : @version =~ /\.\d+\./ ? "'#{@version}'" : "'~> #{@version}.0'"
  end

  def rails_command
    bundle_command = Gem.bin_path('bundler', 'bundle')
    bundle_command = 'bundle' unless bundle_command =~ /bundle/
    rails_cmd_dir = File.expand_path("rails-#{@version}", BASE_PATH)
    rails_path = "#{rails_cmd_dir}/bin/rails"
    command = '"%s" "%s"' % [Gem.ruby, rails_path]
    unless File.exists?(rails_path)
      @logger.info "Creating bootstrap Rails #{@version} bin/rails command"
      FileUtils.rm_rf rails_cmd_dir
      FileUtils.mkdir_p rails_cmd_dir
      Dir.chdir(rails_cmd_dir) do
        File.open("Gemfile", 'w') do |f|
          f.puts "source '#{@gem_source}'"
          f.puts "gem 'rails', #{version_spec}"
          f.puts "gem 'bundler', '~> 1.3'"
        end
        Bundler.with_clean_env do
          system "sh -xc 'time #{bundle_command} install --binstubs' #{@logger.debug? ? '' : ' >> bundle.log 2>&1'}"
        end
      end
      unless File.exists?(rails_path)
        raise BuildError.new("Error getting rails_command: (#{rails_path})")
      end
    end
    command
  end

  def server_command
    find_command("server", "s")
  end

  def generate_command
    find_command("generate", "g")
  end

  def find_command(script_name, rails_arg)
    Dir.chdir(@root) do
      if File.exists?("script/#{script_name}")
        "bundle exec script/#{script_name}"
      elsif File.exists?('script/generate')
        "bundle exec script/rails #{rails_arg}"
      else
        ".bundle/bin/rails #{rails_arg}"
      end
    end
  end


end
