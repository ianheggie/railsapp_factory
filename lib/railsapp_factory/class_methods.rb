require 'cgi'
require 'fileutils'

class RailsappFactory
  module ClassMethods
    # encodes url query arguments, incl nested
    def encode_query(args, prefix = '', suffix = '')
      query = ''
      args.each do |key, value|
        if value.is_a?(Hash)
          query <<= encode_query(value, "#{prefix}#{key}[", "]#{suffix}")
        else
          query <<= '&' << CGI::escape(prefix + key.to_s + suffix) << '=' << CGI::escape(value.to_s)
        end
      end if args
      if prefix == ''
        query.sub(/^&/, '?')
      else
        query
      end
    end

    def cleanup
      FileUtils.rm_rf RailsappFactory::TMPDIR
    end

    def versions(ruby_v = RUBY_VERSION)
      case (ruby_v.to_s)
        when /^1\.8\.6/
          %w{2.3}
        when /^1\.8\.7/
          %w{2.3 2.3-lts 3.0 3.1 3.2}
        when /^1\.9\.1/
          %w{2.3}
        when /^1\.9\.2/
          %w{3.0 3.1 3.2}
        when /^1\.9\.3/
          %w{3.0 3.1 3.2 4.0}
        when /^2\.[01]/
          %w{4.0}
        when /^1\./
          []
        when ''
          # all
          %w{2.3 2.3-lts 3.0 3.1 3.2 4.0}
        else
          %w{4.0} # a guess!
      end
    end

    def rubies(rails_v = nil)
      find_ruby_version_manager
      ruby_command_prefix_template
      result = if @@rbenv_path
                 `#{@@rbenv_path} versions --bare`
               elsif @@rvm_path
                 `#{@@rvm_path} list strings`
               else
                 ''
               end.split(/\r?\n/)
      if rails_v.nil?
        result
      else
        rails_v_compare = rails_v.sub(/^(\d+\.\d+).*?(-lts)?$/, '\1\2')
        result.select do |ruby_v|
          rails_v.nil? || versions(ruby_v).include?(rails_v_compare)
        end
      end
    end

    def ruby_command_prefix(ruby_v = nil)
      if ruby_v.to_s == ''
        ''
      else
        ruby_command_prefix_template % ruby_v.to_s
      end
    end

    def has_ruby_version_manager?
      find_ruby_version_manager != ''
    end

    def rbenv?
      find_ruby_version_manager
      @@rbenv_path
    end

    def rvm?
      find_ruby_version_manager
      @@rvm_path
    end

    def has_ruby_version_manager?
      find_ruby_version_manager != ''
    end

    def using_system_ruby?
      ENV['PATH'] !~ /\/\.?rbenv\/versions\// && ENV['PATH'] !~ /\/\.?rvm\/rubies\//
    end

    private

    def ruby_command_prefix_template
      @@ruby_command_prefix_template ||= begin
        find_ruby_version_manager
        if @@rbenv_path
          "env 'RBENV_VERSION=%s' #{@@rbenv_path} exec"
        elsif @@rvm_path
          "#{@@rvm_path} '%s' do"
        else
          ''
        end
      end
    end


    def find_ruby_version_manager
      @@found_ruby_version_manager ||= begin
        @@rbenv_path = ENV['RBENV_ROOT'] ? "#{ENV['RBENV_ROOT']}/bin/rbenv" : nil
        @@rvm_path = ENV['rvm_path'] ? "#{ENV['rvm_path']}/bin/rvm" : nil
        unless @@rbenv_path || @@rvm_path
          # RubyMine removes RBENV_PATH when a rbenv environment is selected
          ENV['PATH'].split(':').each do |exec_path|
            @@rbenv_path = "#{$1}/bin/rbenv" if exec_path =~ /^(.*\/\.?rbenv)\/(bin|versions)/
            @@rvm_path = "#{$1}/bin/rbenv" if exec_path =~ /^(.*\/\.?rvm)\/(bin|rubies)/
            break if @@rbenv_path || @@rvm_path
          end
          # In case we are running from system ruby and the shell environment is not set
          unless @@rbenv_path || @@rvm_path
            if File.exists? "#{ENV['HOME']}/.rbenv/bin/rbenv"
              @@rbenv_path = "#{ENV['HOME']}/.rbenv/bin/rbenv"
            elsif File.exists? "#{ENV['HOME']}/.rvm/bin/rvm"
              @@rvm_path = "#{ENV['HOME']}/.rvm/bin/rvm"
            end
          end
        end
        @@rbenv_path = nil unless @@rbenv_path && File.exists?(@@rbenv_path)
        @@rvm_path = nil if @@rbenv_path || !@@rvm_path || !File.exists?(@@rvm_path)
        @@rbenv_path || @@rvm_path || ''
      end
    end

  end

end
