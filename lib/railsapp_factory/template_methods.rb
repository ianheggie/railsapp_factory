class RailsappFactory
  module TemplateMethods

    attr_reader :template

    def process_template
      if @template
        if built?
          if @version =~ /^2/
            # recheck config/environment.rb in case the template/s add more config.gem lines
            use_template 'templates/use_bundler_with_rails23.rb'
          end
          template_path = @template
          if @template != /^https?:/ && @template != /^\//
            template_path = File.expand_path(template_path, '.')
          end
          logger.info "Processing template #{template_path}"
          unless system_in_app "sh -xc '.bundle/bin/rake rails:template LOCATION=#{template_path}' #{append_log 'template.log'}"
            raise BuildError.new("rake rails:template returned exist status #{$?} #{see_log 'rails_new.log'}")
          end
          clear_template
        else
          # build actions template
          build
        end
      end
    end

    def append_to_template(text)
      if @readonly_template
        if @template
          text = open(@template).read << text
        end
        template_dir = File.join(base_dir, 'templates')
        FileUtils.mkdir_p template_dir
        @template = Tempfile.new(['append_', '.rb'], template_dir).path
        @readonly_template = false
      end
      open(@template, 'a+') do |f|
        f.puts text
      end
    end

    def use_template(template)
      if @template
        append_to_template(open(template).read)
      else
        @template = template
      end
    end
  end

  private

  def clear_template
    if @template && !@readonly_template
      FileUtils.rm_f @template + '.used'
      FileUtils.move @template, @template + '.used'
    end
    @template = nil
    @readonly_template = true
  end

end
