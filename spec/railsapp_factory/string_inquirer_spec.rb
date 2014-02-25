require 'rspec'

require 'railsapp_factory/string_inquirer'

describe 'RailsappFactory::StringInquirer' do
  subject { RailsappFactory::StringInquirer.new('example_string') }

  it 'should be a kind of string' do
    subject.should be_a_kind_of(String)
  end

  it 'should equal the string it was initialized with' do
    subject.should == 'example_string'
  end

  it 'should respond to example_string? with true' do
    subject.example_string?.should be_true
  end

  it 'should respond to all other questions with false' do
    subject.test?.should be_false
  end

end