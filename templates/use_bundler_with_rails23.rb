# tempplate as per http://bundler.io/v1.5/rails23.html

file 'config/preinitializer.rb', <<-EOF

begin
  require 'rubygems'
  require 'bundler'
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
  raise RuntimeError, "Your bundler version is too old for Rails 2.3.\n" +
   "Run `gem install bundler` to upgrade."
end

begin
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems.\n" +
    "Did you run `bundle install`?"
end

EOF

INSERT_INTO_BOOT = <<-EOF

class Rails::Boot
  def run
    load_initializer

    Rails::Initializer.class_eval do
      def load_gems
        @bundler_loaded ||= Bundler.require :default, Rails.env
      end
    end

    Rails::Initializer.run(:set_load_path)
  end
end

EOF

file_name = 'config/boot.rb'
bak_name = file_name + '.without_bundler'
unless File.exists? bak_name
  FileUtils.move file_name, bak_name
  File.open(file_name, 'w') do |f|
    File.open(bak_name, 'r').each do |line|
      if line =~ /Rails.boot!/
        f.puts INSERT_INTO_BOOT
      end
      f.puts line
    end
  end
end

# Check what has already been done
if File.exists? 'Gemfile'
  File.open('Gemfile', 'r').each do |line|
    has_source ||= line =~ /^\s*source\s/
    has_rails_gem ||= line =~ /^\s*gem\s+['"]rails['"]/
  end
end

#update Gemfile based on what is in
File.open('Gemfile', 'a+') do |gemfile|
  gemfile.puts "source '#{ENV['GEM_SOURCE'] || 'https://rubygems.org'}'" unless has_source
  unless has_rails_gem
    gemfile.puts "gem 'rails', '#{ENV['RAILS_GEM_VERSION'] || '2.3.18'}'"
    gemfile.puts "gem '#{ENV['DB_GEM'] || 'sqlite3'}'"
  end
  file_name = 'config/environment.rb'
  bak_name = file_name + '.bak'
  FileUtils.move file_name, bak_name
    File.open(file_name, 'w') do |f|
      File.open(bak_name, 'r').each do |line|
      if line =~ /^([\s#]*)config\.(gem.*)/
        gemfile.puts "$1$2"
        f.print '# Moved to Gemfile: '
      end
      f.puts line
    end
  end
end
