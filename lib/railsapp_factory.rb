require 'railsapp_factory/version'
require 'tmpdir'
require 'bundler'
require 'fileutils'
require 'tempfile'
require 'logger'
require 'open-uri'

class RailsappFactory

  class BuildError < RuntimeError

  end

  TMPDIR = File.expand_path('tmp/railsapps')

  attr_reader :version # version requested, may be specific release, or the first part of a release number
  attr_reader :pid, :running
  attr_reader :port, :url
  attr_reader :template
  attr_accessor :gem_source, :db, :timeout, :logger

  def initialize(version, logger = Logger.new(STDERR))
    @version = version
    @logger = logger
    throw ArgumentError.new('Invalid version') if version !~ /^[2-9](\.\d+){1,2}$/
    @logger.info("RailsappFactory initialized with version #{version}")
    @gem_source = 'https://rubygems.org'
    @db = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
    @timeout = 300 # 5 minutes
    @files_to_show = ['Gemfile']
    clear_template
  end

  def self.versions(ruby_v = RUBY_VERSION)
    case (ruby_v.to_s)
      when /^1\.8\.6/
        %w{2.3}
      when /^1\.8\.7/
        %w{2.3 3.0 3.1 3.2}
      when /^1\.9\.1/
        %w{2.3}
      when /^1\.9\.2/
        %w{3.0 3.1 3.2}
      when /^1\.9\.3/
        %w{3.0 3.1 3.2 4.0}
      when /^2\.[01]/
        %w{4.0}
      else
        []
    end
  end

  def root
    @root ||= File.join(base_dir, 'railsapp')
  end

  def use_template(template)
    if @template
      Dir.chdir(base_dir) do
        append_to_template(open(template).read)
      end
    else
      @template = template
    end
  end

  def append_to_template(text)
    if @readonly_template
      if @template
        Dir.chdir(base_dir) do
          text = open(@template).read << text
        end
      end
      @template = "#{base_dir}/template.rb"
      @readonly_template = false
    end
    open(@template, 'a+') do |f|
      f.puts text
    end
  end


  def process_template
    if @template
      if built?
        @logger.info "Processing template #{@template}"
        unless in_app { system "sh -xc '.bundle/bin/rake rails:template LOCATION=#{@template}' #{append_log 'template.log'}" }
          raise BuildError.new("rake rails:template #{see_log 'rails_new.log'}")
        end
        clear_template
      else
        # build actions template
        build
      end
    end
  end

  # release installed as reported by the rails command itself
  def release
    @release ||= begin
      cmd = rails_command
      @logger.debug "Getting release using command: #{cmd} '-v'"
      r = in_app(TMPDIR) { `#{cmd} '-v'` }.sub(/^Rails */, '')
      @logger.debug "Release: #{r}"
      r
    end
  end

  def built?
    @built
  end


  def in_app(in_directory = root)
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
    @built = true
    new_arg = version =~ /^[12]/ ? '' : ' new'
    other_args = version =~ /^[12]/ ? '' : '--no-rc' #  '   # --template=TEMPLATE
    other_args <<= ' --edge' if @version == 'edge'
    other_args <<= " -m #{@template}" if @template
    @logger.info "Creating Rails #{@version} app in directory #{root}"
    unless in_app(base_dir) { system "sh -xc '#{rails_command} #{new_arg} railsapp -d #{db} #{other_args}' #{append_log 'rails_new.log'}" }
      raise BuildError.new("rails #{new_arg}railsapp failed #{see_log 'rails_new.log'}")
    end
    clear_template
    expected_file = File.join(root, 'config', 'environment.rb')
    raise BuildError.new("error building railsapp - missing #{expected_file}") unless File.exists?(expected_file)

    unless File.exists?(File.join(root, 'Gemfile'))
      convert_to_use_bundler
    end

    @logger.info "Installing binstubs"
    unless in_app { system "sh -xc 'bundle install --binstubs .bundle/bin' #{append_log 'bundle.log'}" }
      raise BuildError.new("bundle install --binstubs #{see_log 'bundle.log'}")
    end
    raise BuildError.new("error installing gems #{see_log 'bundle.log'}") unless File.exists?(File.join(root, 'Gemfile.lock'))

    if @logger.debug?
      Dir.chdir(root) do
        @files_to_show.sort.uniq.each do |f|
          puts "=" * 30, f, "=" * 30
          puts IO.read(f)
        end
      end
      puts "=" * 30
    end
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
    unless @logger.debug?
      file = Tempfile.new("#{base_dir}/server_log")
      @server_logfile = file.path
      file.close
    end
    @logger.info "Running Rails #{version} server on port #{port} #{see_log @server_logfile}"
    exec_arg = defined?(JRUBY_VERSION) ? '' : 'exec'
    in_app { @server_handle = IO.popen("#{exec_arg} /bin/sh -xc 'exec #{server_command} -p #{port}' #{append_log @server_logfile}", 'w') }
    @pid = @server_handle.pid
    # Detach process so alive? will detect if process dies (zombies still accept signals)
    Process.detach(@pid)

    t1 = Time.new
    while true
      raise TimeoutError.new("Waiting for server to be available on the port #{see_log @server_logfile}") if t1 + @timeout < Time.new
      raise BuildError.new("Error starting server #{see_log @server_logfile}") unless alive?
      sleep(1)
      response = Net::HTTP.get(URI(@url)) rescue nil
      if response
        t2 = Time.new
        @logger.info "Server responded to http GET after %3.1f seconds" % (t2 - t1)
        @running = true
        break
      end
    end
    system "ps -f" if defined?(JRUBY_VERSION) #DEBUG
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
          sleep(1)
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
      FileUtils.rm_rf "#{TMPDIR}/last.#{@version}"
      FileUtils.mv @base_dir, "#{TMPDIR}/last.#{@version}" if File.directory?(@base_dir)
      FileUtils.rm_rf @base_dir
    end
    @base_dir = nil
    @built = false
  end

  def self.cleanup
    FileUtils.rm_rf TMPDIR
  end

  private

  def base_dir
    @base_dir ||= begin
      FileUtils.mkdir_p TMPDIR
      Dir.mktmpdir("app-#{@version}", TMPDIR)
    end
  end

  def clear_template
    if @template && !@readonly_template
      FileUtils.rm_f @template + '.used'
      FileUtils.move @template, @template + '.used'
    end
    @template = nil
    @readonly_template = true
  end

  def version_spec
    @version == 'edge' ? "github: 'rails/rails'" : @version =~ /\.\d+\./ ? "'#{@version}'" : "'~> #{@version}.0'"
  end

  def rails_command
    bundle_command = Gem.bin_path('bundler', 'bundle')
    bundle_command = 'bundle' unless bundle_command =~ /bundle/
    rails_cmd_dir = "#{TMPDIR}/rails-#{@version}"
    rails_path = "#{rails_cmd_dir}/bin/rails"
    command = '"%s" "%s"' % [Gem.ruby, rails_path]
    unless File.exists?(rails_path)
      @logger.info "Creating bootstrap Rails #{@version} as #{rails_path}"
      FileUtils.rm_rf rails_cmd_dir
      FileUtils.mkdir_p rails_cmd_dir
      Dir.chdir(rails_cmd_dir) do
        File.open("Gemfile", 'w') do |f|
          f.puts "source '#{@gem_source}'"
          f.puts "gem 'rails', #{version_spec}"
          f.puts "gem 'bundler', '~> 1.3'"
        end
        Bundler.with_clean_env do
          system "sh -xc '#{bundle_command} install --binstubs' #{append_log 'bundle.log'}"
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
    Dir.chdir(root) do
      if File.exists?("script/#{script_name}")
        "bundle exec script/#{script_name}"
      elsif File.exists?('script/generate')
        "bundle exec script/rails #{rails_arg}"
      else
        ".bundle/bin/rails #{rails_arg}"
      end
    end
  end

  RAILS23_ADD_TO_BOOT = <<-EOF

class Rails::Boot
  def run
    load_initializer

    Rails::Initializer.class_eval do
      def load_gems
        @bundler_loaded ||= Bundler.require :default, Rails.env
      end
    end

    Rails::Initializer.run(:set_load_path)
  end
end

  EOF

  RAILS23_CONFIG_PREINITIALIZER = <<-EOF

begin
  require 'rubygems'
  require 'bundler'
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
  raise RuntimeError, "Your bundler version is too old for Rails 2.3.\n" +
   "Run `gem install bundler` to upgrade."
end

begin
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems.\n" +
    "Did you run `bundle install`?"
end

  EOF


  def convert_to_use_bundler
    @logger.info 'Converting railsapp to use bundler'
    Dir.chdir(root) do
      unless File.exists? 'Gemfile'

        file_name = 'config/boot.rb'
        bak_name = file_name + '.bak'
        FileUtils.move file_name, bak_name
        File.open(bak_name, 'r') do |bak|
          File.open(file_name, 'w') do |f|
            while not bak.eof?
              line = bak.gets
              if line =~ /Rails.boot!/
                f.puts RAILS23_ADD_TO_BOOT
              end
              f.puts line
            end
          end
        end
        @files_to_show <<= file_name

        file_name = 'config/preinitializer.rb'
        File.open(file_name, 'w') do |f|
          f.puts RAILS23_CONFIG_PREINITIALIZER
        end
      end
    end

    file.open('Gemfile', 'w') do |gemfile|

      gemfile.puts "source '#{@gem_source}'"
      gemfile.puts "gem 'rails', '#{@release}'"
      if @db == 'sqlite3'
        gemfile.puts "gem 'sqlite3-ruby', :require => 'sqlite3'"
      else
        gemfile.puts "gem '#{@db}', '#{@release}'"
      end
      file_name = 'config/environment.rb'
      bak_name = file_name + '.bak'
      FileUtils.move file_name, bak_name
      File.open(bak_name, 'r') do |bak|
        File.open(file_name, 'w') do |f|
          while not bak.eof?
            line = bak.gets
            if line =~ /^([\s#]*)config.(gem.*)/
              gemfile.puts "$1$2"
              f.print '# Moved to Gemfile: '
            end
            f.puts line
          end
        end
      end
      @files_to_show <<= file_name
      @files_to_show <<= 'Gemfile'

    end

  end

  def append_log(file)
    @logger.debug? ? '' : " >> #{file} 2>&1"
  end

  def see_log(file)
    @logger.debug? ? '' : " - see #{file}"
  end


end
