# Template to
# add javascript runtime

# Add both gems so that the application is suitable for jruby as well as MRI

require 'fileutils'

gemfile = open('Gemfile').collect {|line| line.chomp}
gemfile0 = gemfile.dup

gemfile.each do |line|
  # change to single quotes
  line.sub!(/"([^"']+)"/, '\'\1\'')
  line.sub!(/platform:/, ':platform =>')
  line.sub!(/require:/, ':require =>')
  if line.sub!(/^\s*(gem\s*['"]sqlite3['"])\s$/, '\1, :platform => :mri')
    puts "Changing gem sqlite to handle multiple platforms"
    gemfile <<= "gem 'sqlite3-ruby', :require => 'sqlite3', platform: :rbx"
    gemfile <<= "gem 'activerecord-sqlite3-adapter', platform: :jruby"
  end

  if line.sub!(/^\s*gem\s*['"]mysql2?['"]\s$/, '\0, :platform => :ruby')
    puts "Changing gem mysql to handle multiple platforms"
    gemfile <<= "gem 'activerecord-jdbcmysql-adapter', platform: :jruby"
  end

  if line.sub!(/^[#\s]*(gem\s*['"]therubyracer['"])\s*$/, '\1, :platform => :ruby')
    puts "Changing gem therubyracer to enable and handle multiple platforms"
    gemfile <<= "gem 'therubyrhino', :platform => :jruby"
  end
end

gemfile <<= "gem 'therubyrhino', :platform => :jruby"
gemfile <<= "gem 'therubyracer', :platform => :ruby"

cleaned_up_gemfile = [ ]
gemfile.each do |line|
  unless line =~ /^gem / && cleaned_up_gemfile.include?(line)
    #puts "Keeping: [#{line}]"
    cleaned_up_gemfile << line
  end
end

if cleaned_up_gemfile != gemfile0
  puts 'Updating Gemfile'
  FileUtils.rm_f 'Gemfile.bak'
  FileUtils.move 'Gemfile', 'Gemfile.bak'
  File.open('Gemfile', 'w') do |f|
    cleaned_up_gemfile.each do |line|
      f.puts line
    end
  end
end


