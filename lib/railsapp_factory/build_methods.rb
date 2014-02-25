class RailsappFactory
  module BuildMethods
    def destroy
      stop
      if @base_dir
        FileUtils.rm_rf "#{TMPDIR}/last.#{@version}"
        FileUtils.mv @base_dir, "#{TMPDIR}/last.#{@version}" if File.directory?(@base_dir)
        FileUtils.rm_rf @base_dir
      end
      @base_dir = nil
      @built = false
      @bundled = false
    end

    def build
      if built?
        @logger.info "Already built Rails #{@version} app in directory #{root}"
        process_template
        return false
      end
      if RUBY_VERSION =~ /^1\.8/
        self.use_template 'templates/add_json_pure.rb'
        if version =~ /^3\.[12]/
          self.use_template 'templates/add_javascript_runtime.rb'
        end
      end
      if version =~ /^2/
        self.use_template 'templates/use_bundler_with_rails23.rb'
      end
      new_arg = version =~ /^2/ ? '' : ' new'
      other_args = version =~ /^2/ ? '' : '--no-rc --skip-bundle'
      other_args <<= ' --edge' if @version == 'edge'
      other_args <<= " -m #{self.template}" if self.template

      @logger.info "Creating Rails #{@version} app in directory #{root}"
      unless in_app('.') { Kernel.system "sh -xc '#{rails_command} #{new_arg} #{root} -d #{db} #{other_args}' #{append_log 'rails_new.log'}" }
        @built = true # avoid repeated build attempts
        raise BuildError.new("rails #{new_arg}railsapp failed #{see_log 'rails_new.log'}")
      end
      @built = true
      clear_template
      expected_file = File.join(root, 'config', 'environment.rb')
      raise BuildError.new("error building railsapp - missing #{expected_file}") unless File.exists?(expected_file)

      command = "sh -xc 'bundle install --binstubs .bundle/bin' #{append_log 'bundle.log'}"
      @logger.info "Installing gems with binstubs using command: #{command}"
      unless system_in_app command
        raise BuildError.new("bundle install returned exit status #{$?} #{see_log 'bundle.log'}")
      end
      @bundled = true
      raise BuildError.new("error installing gems - Gemfile.lock missing #{see_log 'bundle.log'}") unless File.exists?(File.join(root, 'Gemfile.lock'))
      true
    end

    def built?
      @built
    end

    def bundled?
      @bundled
    end

# release installed as reported by the rails command itself
    def release
      @release ||= begin
        cmd = rails_command
        @logger.debug "Getting release using command: #{cmd} '-v'"
        r = in_app(RailsappFactory::TMPDIR) { `#{cmd} '-v'` }.chomp.sub(/^Rails */, '')
        @logger.debug "Release: #{r}"
        r
      end
    end

    def root
      @root ||= File.join(base_dir, 'railsapp')
    end

    private

    def rails_command
      rails_cmd_dir = "#{RailsappFactory::TMPDIR}/rails-#{@version}"
      rails_path = "#{rails_cmd_dir}/bin/rails"
      #command = '"%s" "%s"' % [Gem.ruby, rails_path]
      command = rails_path
      unless File.exists?(rails_path)
        @logger.info "Creating bootstrap Rails #{@version} as #{rails_path}"
        FileUtils.rm_rf rails_cmd_dir
        FileUtils.mkdir_p rails_cmd_dir
        Dir.chdir(rails_cmd_dir) do
          create_Gemfile
          Bundler.with_clean_env do
            Kernel.system "sh -xc '#{bundle_command} install --binstubs' #{append_log 'bundle.log'}"
          end
        end
        unless File.exists?(rails_path)
          raise BuildError.new("Error getting rails_command: (#{rails_path})")
        end
      end
      command
    end

    def create_Gemfile
      version_spec = if @version == 'edge'
                       "github: 'rails/rails'"
                     elsif @version == '2.3-lts'
                       ":git => 'git://github.com/makandra/rails.git', :branch => '2-3-lts'"
                     elsif @version =~ /\.\d+\./
                       "'#{@version}'"
                     else
                       "'~> #{@version}.0'"
                     end
      gemfile_content = <<-EOF
        source '#{@gem_source}'
        gem 'rails', #{version_spec}
      EOF

      File.open('Gemfile', 'w') { |f| f.puts gemfile_content }
      @logger.debug "Created Gemfile with: <<\n#{gemfile_content}>>"
    end

    def base_dir
      @base_dir ||= begin
        FileUtils.mkdir_p RailsappFactory::TMPDIR
        Dir.mktmpdir("app-#{@version.gsub(/\W/, '_')}-", RailsappFactory::TMPDIR)
      end
    end
  end
end
