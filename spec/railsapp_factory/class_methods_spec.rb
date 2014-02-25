require 'rspec'
require "spec_helper"
require 'railsapp_factory/class_methods'

describe 'RailsappFactory::ClassMethods' do

  class SubjectClass
    extend RailsappFactory::ClassMethods
  end

  describe '::versions' do

    it "should list some rails versions that are compatible with ruby #{RUBY_VERSION}" do
      list = SubjectClass.versions
      list.should be_a_kind_of(Array)
      list.should_not be_empty
    end

    it 'should return an empty list for unknown ruby versions' do
      list = SubjectClass.versions('1.5.0')
      list.should be_a_kind_of(Array)
      list.should be_empty
    end

    # taken from http://www.devalot.com/articles/2012/03/ror-compatibility
    {
        '1.something' => [],
        '1.8.6' => %w{2.3},
        '1.8.7' => %w{2.3 2.3-lts 3.0 3.1 3.2},
        '1.9.1' => %w{2.3},
        '1.9.2' => %w{3.0 3.1 3.2},
        '1.9.3' => %w{3.0 3.1 3.2 4.0},
        '2.0.x' => %w{4.0},
        'unknown' => %w{4.0},
        '' => %w{2.3 2.3-lts 3.0 3.1 3.2 4.0}
    }.each do |ruby_v, expected|
      it "should list rails versions that are compatible with ruby #{ruby_v}" do
        list = SubjectClass.versions(ruby_v)
        list.should be_a_kind_of(Array)
        list.should == expected
      end
    end

  end

  describe '::rubies' do

    it 'should list some ruby versions' do
      list = SubjectClass.rubies
      list.should be_a_kind_of(Array)
      list.should_not be_empty
    end

    it 'should return an empty list for unknown rails versions' do
      list = SubjectClass.rubies('1.5.0')
      list.should be_a_kind_of(Array)
      list.should be_empty
    end

    SubjectClass.versions(nil).each do |rails_v|
      it "should only list ruby versions that are compatible with rails #{rails_v}" do
        SubjectClass.rubies(rails_v).each do |ruby_v|
          SubjectClass.versions(ruby_v).should include(rails_v)
        end
      end
    end
  end

  it '::ruby_command_prefix should return a string' do
    res = SubjectClass.ruby_command_prefix
    res.should be_a(String)
  end

  it '::has_ruby_version_manager? should return a Boolean' do
    res = SubjectClass.has_ruby_version_manager?
    res.should be_a(res ? TrueClass : FalseClass)
  end

  it '::using_system_ruby? should return a Boolean' do
    res = SubjectClass.using_system_ruby?
    res.should be_a(res ? TrueClass : FalseClass)
  end

  describe '::ruby_command_prefix' do
    include ::SpecHelper

    SubjectClass.rubies.each do |ruby_v|
      it "provides a command prefix that will run ruby #{ruby_v}" do
        prefix = SubjectClass.ruby_command_prefix(ruby_v)
        #puts "RailsappFactory.ruby_command_prefix(#{ruby_v}) = '#{prefix}'"
        actual_ruby_v=`#{prefix} ruby -v`
        actual_version_should_match_rubies_version(actual_ruby_v, ruby_v)
      end
    end

  end

  describe '::encode_query' do

    it 'should encode a simple argument' do
      SubjectClass.encode_query(:ian => 23).should == '?ian=23'
    end

    it 'should encode a nested argument' do
      SubjectClass.encode_query(:author => {:ian => 23}).should == '?author%5Bian%5D=23'
    end

    it 'should encode a multiple arguments' do
      res = SubjectClass.encode_query(:ian => 23, :john => '45')
      #order not guaranteed
      if res =~ /^.ian/
        res.should == '?ian=23&john=45'
      else
        res.should == '?john=45&ian=23'
      end
    end

  end

end

