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

     # you can also append to the template defined above, or start a custom template from scratch by using
     # template <<=
     # A temp file is created containing the combined template information

     railsapp.template <<= <<-EOF
        gem "my_gem_name", :path => '#{File.expand_path('templates/add-file.rb', '..')}'
        bundle install
        generate(:scaffold, "person name:string")
        route "root to: 'people#index'"
        rake("db:migrate")
     EOF

     # following commands return a struct with stdout, stderr and exit_status
     # and an exception is raised if build fails

     puts "Latest version in #{version} series is #{railsapp.version}"
     railsapp.build   # run,rake,runner,console will all trigger this if you forget

     railsapp.template <<= 'gem "halo"'

     railsapp.apply_template  # apply template with rake command

     #TODO: railsapp.runner 'Some.ruby(code)'
     #TODO: railsapp.runner 'filename'
     #TODO: railsapp.console do |f|
     #TODO:   f.puts "Some.ruby(code)"
     #TODO:   f.puts "More.ruby(code)"
     #TODO: end

     #TODO: railsapp.eval 'Some.ruby(code)'  # adds .to_json on the end of the expression, then parses output for json and returns result

     railsapp.run

     # check server actually ran
     railsapp.alive?.should be_true
     #TODO: railsapp.get("/health_check") - returns status same as get in tests
     #TODO: railsapp.post("/health_check") - returns status same as post in tests
     puts "url: #{railsapp.url}"
     puts "port: #{railsapp.port}"
     railsapp.stop

     railsapp.in_app do
       # runs command in rails root dir without the extra environment variables bundler exec sets"
       system 'some command'
     end
     railsapp.destroy
   end

   # removes all temp directories - TODO: stop any running servers
   RailsappFactory.cleanup



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

