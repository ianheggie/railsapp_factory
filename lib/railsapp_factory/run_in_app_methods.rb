class RailsappFactory
  module RunInAppMethods
    def in_app(in_directory = built? ? root : base_dir)
      Dir.chdir(in_directory) do
        setup_env do
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

# returns value from ruby command run in ruby, serialized via to_json to keep to simple values
    def ruby_eval(expression, evaluate_with = :ruby)
      result = nil
      script_file = Tempfile.new("#{base_dir}/#{evaluate_with}_script")
      expression_file = script_file.path
      json_file = "#{expression_file}.json"
      script_contents = <<-EOF
      require 'json'; value = begin; def value_of_expression; #{expression}
        end
        { 'value' => value_of_expression }
      rescue Exception => ex
        { 'exception' => ex.class.to_s, 'message' => ex.message, 'backtrace' => ex.backtrace }
      end
      File.open('#{json_file}', 'w') do |_script_output|
         _script_output.puts value.to_json
      end
      EOF
      script_file.puts script_contents
      script_file.close
      @logger.debug "#{evaluate_with}_eval running script #{expression_file} #{see_log('eval.log')}"
      command = if evaluate_with == :ruby
                  'bundle exec ruby'
                elsif evaluate_with == :runner
                  runner_command
                else
                  raise ArgumentError.new("invalid evaluate_with argument")
                end
      system_in_app "sh -xc '#{command} #{expression_file}' #{append_log('eval.log')}"
      if File.size?(json_file)
        res = JSON.parse(File.read(json_file))
        FileUtils.rm_f json_file
        if res.include? 'value'
          result = res['value']
        elsif res.include? 'exception'
          result = begin
            Object.const_get(res['exception']).new(res['message'] || 'Unknown')
          rescue
            RuntimeError.new("#{res['exception']}: #{res['message']}")
          end
          result.set_backtrace(res['backtrace'] + get_backtrace) if res['backtrace']
          raise result
        end
      else
        result = ArgumentError.new("unknown error, probably syntax (missing #{json_file}) #{see_log('eval.log')}")
        raise result
      end
      result
    end

# returns value from expression passed to runner, serialized via to_json to keep to simple values
    def rails_eval(expression)
      ruby_eval(expression, :runner)
    end

    def shell_eval(*args)
      arg = args.count == 1 ? args.first : args
      in_app { IO.popen(arg, 'r').read }
    end

    def system_in_app(*args)
      in_app { Kernel.system(*args) }
    end


    private
    def setup_env
      Bundler.with_clean_env do
        @override_ENV.each do |key, value|
          unless %w{RAILS_ENV RACK_ENV}.include? key
            @logger.debug "setup_env: setting ENV[#{key.inspect}] = #{value.inspect}"
            ENV[key] = value
          end
        end
        rails_env = self.env.to_s
        ENV['RAILS_ENV'] = ENV['RACK_ENV'] = rails_env
        @logger.debug "setup_env: setting ENV['RAILS_ENV'] = ENV['RACK_ENV'] = #{rails_env.inspect}"
        ENV['GEM_SOURCE'] = @gem_source
        ENV['RAILS_GEM_VERSION'] = @release
        ENV['DB_GEM'] = @db
        yield
      end
    end
  end
end
