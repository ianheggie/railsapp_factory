require 'logger'
require 'railsapp_factory/string_inquirer'

class RailsappFactory
  module HelperMethods

    attr_writer :logger

    attr_accessor :gem_source, :db, :timeout, :logger

    def override_ENV
      @override_ENV ||= {}
    end

    def logger
      @logger ||= Logger.new(STDERR)
    end

    def uri(path = '', query_args = {})
      URI(self.url(path, query_args))
    end

    def url(path = '', query_args = {})
      "http://127.0.0.1:#{self.port}/" + path.to_s.sub(/^\//, '') + self.class.encode_query(query_args)
    end

    def env=(value)
      self.override_ENV['RAILS_ENV'] = value
      self.override_ENV['RACK_ENV'] = value
      self.env
    end

    def env
      rails_env = self.override_ENV['RAILS_ENV'] || self.override_ENV['RACK_ENV'] || 'test'
      @_env = nil unless @_env.to_s == rails_env
      @_env ||= RailsappFactory::StringInquirer.new(rails_env)
    end

    #def rubies(rails_v = @version)
    #  self.class.rubies(rails_v)
    #end

    def alive?
      if @pid
        begin
          Process.kill(0, @pid)
          self.logger.debug "Process #{@pid} is alive"
          true
        rescue Errno::EPERM
          self.logger.warning "Process #{@pid} has changed uid - we will not be able to signal it to finish"
          true # changed uid
        rescue Errno::ESRCH
          self.logger.debug "Process #{@pid} not found"
          false # NOT running
        rescue Exception => ex
          self.logger.warning "Process #{@pid} in unknown state: #{ex}"
          nil # Unable to determine status
        end
      end
    end

    private

    # get backtrace except for this method

    def get_backtrace
      raise 'get backtrace'
    rescue => ex
      trace = ex.backtrace
      trace.shift
      trace
    end

    def see_log(file)
      self.logger.debug? ? '' : " - see #{file}"
    end

    def append_log(file)
      self.logger.debug? ? '' : " >> #{file} 2>&1"
    end

    def bundle_command
      "#{self.class.ruby_command_prefix(self.using)} bundle"
    end

    def ruby_command(bundled = true)
      "#{self.class.ruby_command_prefix(self.using)} #{bundled ? 'bundle exec' : ''} ruby"
    end

    def find_command(script_name, rails_arg)
      result = Dir.chdir(root) do
        if File.exists?("script/#{script_name}")
          "#{bundle_command} exec script/#{script_name}"
        elsif File.exists?('script/rails')
          "#{bundle_command} exec script/rails #{rails_arg}"
        else
          "#{ruby_command(false)} .bundle/bin/rails #{rails_arg}"
        end
      end
      self.logger.info("find_command(#{script_name.inspect}, #{rails_arg.inspect}) returned #{result.inspect}")
      result
    end

    def generate_command
      find_command('generate', 'generate')
    end

    def runner_command
      find_command('runner', 'runner')
    end

    def server_command
      find_command('server', 'server')
    end

  end

end
