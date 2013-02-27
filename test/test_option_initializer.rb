$VERBOSE = true

require 'rubygems'
require 'minitest/autorun'
require 'option_initializer'

class MyClass
  include OptionInitializer
  option_initializer :aaa, :bbb
  option_initializer :ccc, :ddd
  option_initializer :ccc, :ddd

  attr_reader :a, :b, :options, :y

  def initialize a, b, opts
    @a = a
    @b = b
    @options = opts

    @y = yield if block_given?
  end
end

class MyClass2
  include OptionInitializer
  include OptionInitializer

  option_initializer :aaa, :bbb, :ccc
  option_validator do |k, v|
    case k
    when :aaa
      raise ArgumentError if v == 0
    end
  end
  option_validator do |k, v|
    case k
    when :aaa
      raise ArgumentError if v < 0
    end
  end

  def initialize options
    @options = options
  end

  def num_options bool
    @options.length if bool
  end

  def echo a
    yield a
  end
end

# Excerpt from README
class Person
  include OptionInitializer
  option_initializer :id, :name, :age, :greetings

  def initialize opts
    @options = opts
  end

  def say_hello
    puts @options[:greetings].call @options[:name]
  end
end

class TestOptionInitializer < MiniTest::Unit::TestCase
  def test_oi
    o = MyClass.aaa(1).bbb(2).ddd { 4 }.ccc(3).new(1, 2)
    assert_equal 1, o.options[:aaa]
    assert_equal 2, o.options[:bbb]
    assert_equal 3, o.options[:ccc]
    assert_equal 4, o.options[:ddd].call
    assert_equal 1, o.a
    assert_equal 2, o.b
    assert_equal nil, o.y

    o = MyClass.aaa(1).bbb(2).ccc(3).aaa(4).new(1, 2, :ddd => 4) { :y }
    assert_equal 4, o.options[:aaa]
    assert_equal 2, o.options[:bbb]
    assert_equal 3, o.options[:ccc]
    assert_equal 4, o.options[:ddd]
    assert_equal 1, o.a
    assert_equal 2, o.b
    assert_equal :y, o.y

    assert_instance_of MyClass::OptionInitializing, MyClass.aaa(1)

    assert_raises(ArgumentError) { MyClass.aaa(1) { 1 } }
    assert_raises(ArgumentError) { MyClass.aaa(1, 2) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1, 2, 3) }
  end

  def test_method_missing
    assert_equal 2, MyClass2.aaa(1).bbb(2).num_options(true)
    assert_equal 2, MyClass2.aaa(1).bbb(2).echo(1) { |a| a * 2 }
  end

  def test_validator
    assert_raises(ArgumentError) { MyClass2.aaa(0) }
    assert_raises(ArgumentError) { MyClass2.aaa(-1) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(-1) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(1).new(:aaa => -2) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(1).new(:aaa => -2) }
  end

  def test_readme
    john = Person.name('John Doe').age(19).greetings { |name| "Hi, I'm #{name}!" }.id(1000).new
    john = Person.new :id => 1000, :name => 'John Doe', :age => 19, :greetings => proc { |name| "Hi, I'm #{name}!" }
    Person.name('John Doe').age(19).greetings { |name| "Hi, I'm #{name}!" }.id(1000).say_hello
  end
end

