# Template to
# add javascript runtime

if defined?(JRUBY_VERSION)
  gem "therubyrhino"
else
  gem "therubyracer"
end
