require 'cgi'

class RailsappFactory
  module ClassMethods
    # encodes url query arguments, incl nested
    def encode_query(args, prefix = '', suffix = '')
      query = ''
      args.each do |key, value|
        if value.is_a?(Hash)
          query <<= RailsappFactory.encode_query(value, "#{prefix}#{key}[", "]#{suffix}")
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
          [ ]
        else
          %w{4.0}   # a guess!
      end
    end

  end
end
