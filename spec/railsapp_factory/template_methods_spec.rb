require 'rspec'
require 'spec_helper'

require 'railsapp_factory/class_methods'
require 'railsapp_factory/template_methods'
require 'railsapp_factory/helper_methods'

describe 'RailsappFactory::TemplateMethods' do

  class SubjectClass
    extend RailsappFactory::ClassMethods
    # include for logger
    include RailsappFactory::HelperMethods
    include RailsappFactory::TemplateMethods

    def base_dir
      "/tmp"
    end

    def version
      '4.0'
    end
  end

  subject { SubjectClass.new }

  describe '#process_template' do
    it 'should call nothing when nothing has been added' do
      subject.process_template
      subject.template.should be_nil
    end

    describe 'with template contents' do
      before { subject.append_to_template('gem "one"') }

      it "should have contents" do
        subject.template.should_not be_nil
        File.size?(subject.template).should be_true
      end

      describe "before build" do
        before { subject.stub(:built?).and_return(false) }
        it "should call build" do
          subject.built?.should be_false
          subject.should_receive(:build).with()
          subject.process_template
          # checked elsewhere that build clears the template
        end
      end

      describe "when built" do
        before { subject.stub(:built?).and_return(true) }
        it "should call process_template" do
          subject.should_receive(:system_in_app).and_return(true)
          subject.process_template
          subject.template.should be_nil
        end
      end
    end
  end


  it '#append_to_template(text) should append text to a template' do
    subject.append_to_template('gem "one"')
    subject.append_to_template('gem "two"')
    File.exist?(subject.template).should be_true
    File.read(subject.template).should include("\ngem \"one\"\n")
    File.read(subject.template).should include("\ngem \"two\"\n")
  end

  it '#use_template(template) should append text to a template from a local file' do
    subject.use_template('templates/add_json_pure.rb')
    File.exist?(subject.template).should be_true
    File.read(subject.template).should include("\ngem 'json_pure'\n")
  end

  it '#use_template(template) should append text to a template from a remote file' do
    subject.use_template('https://raw2.github.com/ianheggie/railsapp_factory/master/spec/templates/add-file.rb')
    File.exist?(subject.template).should be_true
    File.read(subject.template).should include("file.txt")
  end

  it 'should merge the contents of multiple appends and use_template calls' do
    subject.append_to_template('gem "one"')
    subject.use_template('templates/add_json_pure.rb')
    subject.append_to_template('gem "two"')
    subject.use_template('https://raw2.github.com/ianheggie/railsapp_factory/master/spec/templates/add-file.rb')
    File.exist?(subject.template).should be_true
    File.read(subject.template).should include("\ngem \"one\"\n")
    File.read(subject.template).should include("\ngem \"two\"\n")
    File.read(subject.template).should include("\ngem 'json_pure'\n")
    File.read(subject.template).should include("file.txt")
  end


end


