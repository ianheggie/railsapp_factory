require 'fileutils'
require 'open-uri'

require 'railsapp_factory/build_error'

class RailsappFactory
  module TemplateMethods

    attr_reader :template

    def process_template
      if self.template
        if self.built?
          if self.version =~ /^2/
            # recheck config/environment.rb in case the template/s add more config.gem lines
            use_template 'templates/use_bundler_with_rails23.rb'
          end
          self.logger.info "Processing template #{@template}"
          unless self.system_in_app "sh -xc '.bundle/bin/rake rails:template LOCATION=#{@template}' #{append_log 'template.log'}"
            raise RailsappFactory::BuildError.new("rake rails:template returned exist status #{$?} #{see_log 'rails_new.log'}")
          end
          clear_template
        else
          # build actions template
          self.build
        end
      end
    end

    def append_to_template(text, source="append_to_template")
      unless @template
        template_dir = File.join(base_dir, 'templates')
        FileUtils.mkdir_p(template_dir) unless File.directory?(template_dir)
        @template = Tempfile.new('append_', template_dir).path + '.rb'
      end
      open(@template, 'a+') do |f|
        f.puts "\n# #{source}:"
        f.puts text
      end
    end

    def use_template(template)
      append_to_template(open(template).read, "use_template(#{template}")
    end

    protected

    def clear_template
      @template = nil
    end

  end

end
