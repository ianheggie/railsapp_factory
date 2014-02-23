require 'json'
require 'yaml'
require 'tempfile'

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
    def ruby_eval(expression, serialize_with = :json, evaluate_with = :ruby)
      result = nil

      evaluate_with = :runner if RUBY_VERSION =~ /^1\.8/ and serialize_with == :json
      script_file = Tempfile.new("#{evaluate_with}_script", base_dir)
      expression_file = script_file.path
      output_file = "#{expression_file}.output"
      script_contents = <<-EOF
      require '#{serialize_with}'; value = begin; def value_of_expression; #{expression}
        end
        { 'value' => value_of_expression }
      rescue Exception => ex
        { 'exception' => ex.class.to_s, 'message' => ex.message, 'backtrace' => ex.backtrace }
      end
      File.open('#{output_file}', 'w') do |_script_output|
         _script_output.puts value.to_#{serialize_with}
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
      @logger.info("#{evaluate_with}_eval of #{expression} returned exit status of #{$?}")
      if File.size?(output_file)
        res = if serialize_with == :json
                JSON.parse(File.read(output_file))
              else
                YAML.load_file(output_file)
              end
        FileUtils.rm_f output_file
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
        result = ArgumentError.new("unknown error, probably syntax (missing #{output_file}) #{see_log('eval.log')}")
        raise result
      end
      result
    end

# returns value from expression passed to runner, serialized via to_json to keep to simple values
    def rails_eval(expression, serialize_with = :json)
      ruby_eval(expression, serialize_with, :runner)
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
