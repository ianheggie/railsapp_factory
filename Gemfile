source 'https://rubygems.org'

# Specify your gem's dependencies in railsapp_factory.gemspec
gemspec

if RUBY_VERSION < '1.9'
  # mime-types 2.0 requires Ruby version >= 1.9.2
  gem 'mime-types', '< 2.0'
elsif RUBY_VERSION < '2.0'
  # mime-types 3.0 requires Ruby version >= 2.0
  gem 'mime-types', '< 3.0'
end

