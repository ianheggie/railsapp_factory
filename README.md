# RailsappFactory

Rails application factory to make testing gems against multiple versions easier

## Installation

Add this line to your application's Gemfile:

    gem 'railsapp_factory'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install railsapp_factory

## Usage

To get the list of available versions (that can be run with the ruby version you are currently running):

   RailsappFactory.versions

Depending on the ruby version in use, it will suggest versions '2.3', '3.0', '3.1', '3.2' and '4.0'. The latest in each series will be downloaded. You can also specify a specific version, eg '3.2.8' or 'edge' (edge has to be selected manually as unforsean changes may break the standard build process).

The INTENT is to end up with:

To test a gem (health_check in this case), run:

   RailsappFactory.versions.each do |version|
     railsapp = RailsappFactory.new(version)  # also accepts "edge"
     railsapp.timeout = 300  # timeout operations after 300 seconds
     railsapp.template = File.expand_path('templates/add-file.rb', File.dirname(__FILE__)) # ie full path name
     # OR
     railsapp.template = "http://example.com/example.rb"

     # you can also append to the template defined above, or start a custom template from scratch by using append_to_template
     # A temp file is created containing the combined template information

     railsapp.append_to_template <<-EOF
        gem "my_gem_name", :path => '#{File.expand_path('templates/add-file.rb', '..')}'
        bundle install
        generate(:scaffold, "person name:string")
        route "root to: 'people#index'"
        rake("db:migrate")
     EOF

     # following commands return a struct with stdout, stderr and exit_status
     # and an exception is raised if build fails

     puts "Latest version in #{railsapp.release} series is #{railsapp.version}"

     railsapp.build   # run,rake,runner,console will all trigger this if you forget

     railsapp.append_to_template 'gem "halo"'

     railsapp.process_template  # apply template with rake command

     # runs an expression in runner and ruby respectively, and uses to_json to return the result.
     # exceptions are passed through, except for syntax errors

     railsapp.rails_eval 'Some.rails(code)'     # with rails loaded
     railsapp.ruby_eval 'Some.ruby(code)'       # without rails (except for 2.3* which requires rails to pass results back)

     railsapp.run

     # check server is actually running
     railsapp.alive?.should be_true

     # some helpers for constructing urls (strings)
     puts "home url: #{railsapp.url}"
     puts "url: #{railsapp.url('/search', {:author => {:name => 'fred'}})"

     puts "Instance of URI: #{railsapp.uri('/some/path', :name => 'value')}"

     puts "port: #{railsapp.port}"

     railsapp.stop

     # override ENV passed to rails app processes
     railsapp.override_ENV['EDITOR'] = 'vi'

     railsapp.in_app do
                 # runs command in rails root dir without the extra environment variables bundler exec sets"
       system 'some shell command'
     end

     railsapp.system_in_app 'another shell command'

     railsapp.destroy
   end

   # removes all temp directories - TODO: stop any running servers
   RailsappFactory.cleanup

If you use rvm (eg travis.ci) or rbenv (like I do), then you also go the other way,
and run you tests in a specific version of ruby (eg to use the later syntax), but build and/or run the rails app
with the various ruby versions you have installed.

It will attempt to find rvm / rbenv through environment variabkes first, the check the PATH, and lastly check the standard install directories under $HOME.
This handles RubyMine's clearing of environment variables, running rbenv or rvm in command mode only whilst running the system ruby.

    RailsappFactory.rubies                    # lists all ruby versions available (in the format the version manager prefers)
    RailsappFactory.rvm?                      # is RVM available
    RailsappFactory.rbenv?                    # is rbenv available
    RailsappFactory.has_ruby_version_manager? # either available?
    RailsappFactory.using_system_ruby?        # simple check that there are no rvm or rbenv specific directories in PATH

    # example without having to build the actual rails app (run ruby commands)

    RailsappFactory.rubies.each do |ruby_v|
      it "provides a command prefix that will run ruby #{ruby_v}" do
        prefix = RailsappFactory.ruby_command_prefix(ruby_v)
        actual_ruby_v=`#{prefix} ruby -v`
      end
    end

    # example for a rail application

    @factory = RailsappFactory.new   # chooses the most recent rails version compatible with RUBY_VERSION

    @factory.rubies.each do |ruby_v|
      @factory.use(ruby_v)
      actual_ruby_v = @factory.rails_eval('RUBY_VERSION')
      puts "Using #{@factory.using} ruby"
    end
    @factory.use(nil)  # revert to the default ruby (in PATH)

    # You can also pass use a block, and it will revert the ruby version afterwards
    @factory.use(ruby_v)
      actual_ruby_v = @factory.rails_eval('RUBY_VERSION')
    end


I am considering get/put like integration tests have, but requires some thought first to be non rails version specific

   #TODO: railsapp.get("/some/path") - returns status same as get in tests
   #TODO: railsapp.post("/another/path", :author => { :name => 'fred' } ) - returns status same as post in tests


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT - See LICENSE.txt
