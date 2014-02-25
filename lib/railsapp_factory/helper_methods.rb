class RailsappFactory
  module HelperMethods

    def uri(path = '', query_args = {})
      URI(self.url(path, query_args))
    end

    def url(path = '', query_args = {})
      "http://127.0.0.1:#{self.port}/" + path.to_s.sub(/^\//, '') + RailsappFactory.encode_query(query_args)
    end

    def env=(value)
      @override_ENV['RAILS_ENV'] = value
      @override_ENV['RACK_ENV'] = value
      self.env
    end

    def env
      @_env = nil unless @_env.to_s == @override_ENV['RAILS_ENV']
      @_env ||= RailsappFactory::StringInquirer.new(@override_ENV['RAILS_ENV'] || @override_ENV['RACK_ENV'] || 'test')
    end

    def rubies(rails_v = @version)
      RailsappFactory.rubies(rails_v)
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
      @logger.debug? ? '' : " - see #{file}"
    end

    def append_log(file)
      @logger.debug? ? '' : " >> #{file} 2>&1"
    end

    def bundle_command
      "#{RailsappFactory.ruby_command_prefix(@using)} bundle"
    end

    def ruby_command(bundled = true)
      "#{RailsappFactory.ruby_command_prefix(@using)} #{bundled ? 'bundle exec' : ''} ruby"
    end

    def find_command(script_name, rails_arg)
      Dir.chdir(root) do
        if File.exists?("script/#{script_name}")
          "#{bundle_command} exec script/#{script_name}"
        elsif File.exists?('script/rails')
          "#{bundle_command} exec script/rails #{rails_arg}"
        else
          "#{ruby_command(false)} .bundle/bin/rails #{rails_arg}"
        end
      end
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
