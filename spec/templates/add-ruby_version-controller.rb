generate :controller, 'ruby_version', 'index'

file 'app/controllers/ruby_version_controller.rb', <<-TEXT
class RubyVersionController < ApplicationController
  def index
    render :text => RUBY_VERSION
  end
end
TEXT