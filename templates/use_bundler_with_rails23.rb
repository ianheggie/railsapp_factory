# Template to
# 1. update rails 2.3 to using bundler as per http://bundler.io/v1.5/rails23.html
#    - copies gem details from config/environment.rb to Gemfile and comments them out in environment.rb file
# 2. fix broken require in Rakefile
# 3. update to rails-lts (unless RAILS_LTS env var is set to false)
#
# Template is safe to apply multiple times


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
mentions_bundler = false
File.open(file_name).each do |line|
  mentions_bundler ||= line =~ /Bundler\./
end

unless mentions_bundler
  puts "    updating  #{file_name} - inserting bundler code"
  bak_name = file_name + '.without_bundler'
  unless File.exists? bak_name
    FileUtils.move file_name, bak_name
    File.open(file_name, 'w') do |f|
      File.open(bak_name).each do |line|
        if line =~ /Rails.boot!/
          f.puts INSERT_INTO_BOOT
        end
        f.puts line
      end
    end
  end
end

# Check what has already been done
has_source = false
has_gem = {}
if File.exists? 'Gemfile'
  File.open('Gemfile', 'r').each do |line|
    has_source ||= line =~ /^\s*source\s/
    if line =~ /^\s*gem\s+['"]([^'"]+)['"]/
      has_gem[$1] = line
    end
  end
end

#update Gemfile based on what is in config/environment.rb
File.open('Gemfile', 'a+') do |gemfile|
  unless has_source
    gemfile.puts "source '#{ENV['GEM_SOURCE'] || 'https://rubygems.org'}'"
  end

  # make sure rails is in the gem list
  unless has_gem['rails']
    rails_gem_version = nil
    open('config/environment.rb').each do |line|
      if line =~ /^RAILS_GEM_VERSION\s*=\s*\D(2\.3\.\d+)\D/
        rails_gem_version = $1
      end
    end
    rails_gem_version ||= '2.3.18'

    if ENV['RAILS_LTS'] == 'false'
      # a different version has been deliberately picked
      has_gem['rails'] = "gem 'rails', '#{rails_gem_version}'"
      gemfile.puts has_gem['rails']
      puts "    updating  Gemfile - adding rails gem #{rails_gem_version}"
    else
      has_gem['rails'] = "gem 'rails', :git => 'git://github.com/makandra/rails.git', :branch => '2-3-lts'"
      gemfile.puts has_gem['rails']
      if rails_gem_version != '2.3.18'
        puts 'WARNING - RAILS_GEM_VERSION needs to be updated to 2.3.18 in config/environment.rb!'
      end
      puts "    updating  Gemfile - adding rails gem #{rails_gem_version}-lts"
    end
  end

  # make sure database adapters are in the list
  open('config/database.yml').each do |line|
    if line =~ /^\s*adapter:\s*['"]?([^'"\s]+)/
      adapter = $1
      unless has_gem[adapter]
        gemfile.puts "gem '#{adapter}'  # used in database.yml"
        puts "    updating  Gemfile - adding #{adapter} gem # used in database.yml"
        has_gem[adapter] = true
      end
    end
  end

  # copy over other gem definitions
  file_name = 'config/environment.rb'
  bak_name = file_name + '.bak'
  FileUtils.rm_f bak_name
  FileUtils.move file_name, bak_name
  File.open(file_name, 'w') do |f|
    File.open(bak_name, 'r').each do |line|
      if line =~ /^([\s#]*)config\.(gem.*)/
        prefix = $1
        command = $2
        prefix.sub!(/^\s+/, '')
        command.sub!(/:version *=>/, ' ')
        command.sub!(/:lib/, ':require')
        if line =~ /^\s*config.gem\s+['"]([^'"]+)['"]/
          prefix = '# ' if has_gem[$1]
          has_gem[$1] = line
          puts "    updating  Gemfile - adding #{$1} gem" if prefix !~ /#/
        end
        gemfile.puts "#{prefix}#{command} # converted from: #{line}"
        f.print '# Moved to Gemfile: '
      end
      f.puts line
    end
  end

  unless has_gem['json_pure']
    gemfile.puts "gem 'json_pure'  # used by RailsapFactory *_eval methods"
    puts '    updating  Gemfile - adding json_pure gem # used by RailsapFactory *_eval methods'
  end

end

# Fix ERROR: 'rake/rdoctask' is obsolete and no longer supported. Use 'rdoc/task' (available in RDoc 2.4.2+) instead.
# .../railsapp/Rakefile:8

file_name = 'Rakefile'
bak_name = file_name + '.bak'
unless File.exists? bak_name
  FileUtils.move file_name, bak_name
  File.open(file_name, 'w') do |f|
    File.open(bak_name, 'r').each do |line|
      if line =~ /rake.rdoctask/
        line = "# require 'rdoc/task' # replaces outs of date: #{line}"
        puts '    updating Rakefile - fixing rake/rdoctask line'
      end
      f.puts line
    end
  end
end

%w{Gemfile config/environment.rb Rakefile}.each do |file|
  puts '=' * 50, file, '=' * 50
  puts File.read(file)
end
puts '=' * 50, 'END OF TEMPLATE'

