# Template to
# add javascript runtime

# Add both gems so that the application is suitable for jruby as well as MRI
gem 'therubyrhino', :platform => :jruby
gem 'therubyracer', :platform => :ruby
