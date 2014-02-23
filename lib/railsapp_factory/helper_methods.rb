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
      @_env ||= RailsappFactory::StringInquirer.new(@override_ENV["RAILS_ENV"] || @override_ENV["RACK_ENV"] || "test")
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

    def find_command(script_name, rails_arg)
      Dir.chdir(root) do
        if File.exists?("script/#{script_name}")
          "bundle exec script/#{script_name}"
        elsif File.exists?('script/rails')
          "bundle exec script/rails #{rails_arg}"
        else
          ".bundle/bin/rails #{rails_arg}"
        end
      end
    end

    def generate_command
      find_command("generate", "generate")
    end

    def runner_command
      find_command("runner", "runner")
    end

    def server_command
      find_command("server", "server")
    end

  end

end
