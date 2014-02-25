require 'json'
require 'yaml'
require 'tempfile'

class RailsappFactory
  module RunInAppMethods

    attr_reader :using

    def use(ruby_v)
      if block_given?
        begin
          orig_using = @using
          @using = ruby_v.to_s
          result = yield
        ensure
          @using = orig_using
        end
      else
        result = @using = ruby_v.to_s
      end
      result
    end

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
                  ruby_command(bundled?)
                elsif evaluate_with == :runner
                  runner_command
                else
                  raise ArgumentError.new('invalid evaluate_with argument')
                end
      system_in_app "sh -xc '#{command} #{expression_file}' #{append_log('eval.log')}"
      @logger.info("#{evaluate_with}_eval of #{expression} returned exit status of #{$?} - #{expression_file}")
      if File.size?(output_file)
        res = if serialize_with == :json
                JSON.parse(File.read(output_file))
              else
                YAML.load_file(output_file)
              end
        FileUtils.rm_f output_file
        FileUtils.rm_f expression_file
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
        result = ArgumentError.new("unknown error, possibly a syntax error, (missing #{output_file}) #{see_log('eval.log')} - #{expression_file} contains:\n#{command}")
        raise result
      end
      result
    end

# returns value from expression passed to runner, serialized via to_json to keep to simple values
    def rails_eval(expression, serialize_with = :json)
      ruby_eval(expression, serialize_with, :runner)
    end

    def shell_eval(*args)
      arg = prepend_ruby_version_command_to_arg(args)
      in_app { IO.popen(arg, 'r').read }
    end

    def prepend_ruby_version_command_to_arg(args)
      arg = args.count == 1 ? args.first : args
      command_prefix = RailsappFactory.ruby_command_prefix(@using)
      if arg.kind_of?(Array)
        arg = command_prefix.split(' ') + arg
      else
        arg = "#{command_prefix} #{arg}"
      end
      arg
    end

    def system_in_app(*args)
      arg = prepend_ruby_version_command_to_arg(args)
      in_app { Kernel.system(arg) }
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
        ENV['RAILS_LTS'] = if @version =~ /lts/ then
                             'true'
                           elsif @version =~ /^2\.3/
                             'false'
                           else
                             nil
                           end
        ENV['GEM_SOURCE'] = @gem_source if ENV['RAILS_LTS']
        @logger.debug "setup_env: setting ENV['GEM_SOURCE'] = #{@gem_source.inspect}, ENV['RAILS_LTS'] = #{ENV['RAILS_LTS'].inspect}" if ENV['RAILS_LTS']
        #if @using != '' && RailsappFactory.rbenv?
        #ENV['RBENV_VERSION'] = @using
        #@logger.debug "setup_env: setting ENV['RBENV_VERSION'] = #{@using.inspect}"
        #end
        yield
      end
    end
  end
end
