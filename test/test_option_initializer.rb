$VERBOSE = true

require 'rubygems'
require 'minitest/autorun'
require 'option_initializer'

class MyClass
  include OptionInitializer
  option_initializer :aaa, :bbb => 1
  option_initializer :ccc, :ddd
  option_initializer :ccc, :ddd => :block

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

  @@validate_count = 0

  def self.reset_count
    @@validate_count = 0
  end

  def self.count
    @@validate_count
  end

  option_initializer! :aaa
  option_initializer  :bbb, :ccc
  option_validator do |k, v|
    @@validate_count += 100
    case k
    when :aaa
      raise ArgumentError
    end
  end
  option_validator do |k, v|
    @@validate_count += 1
    case k
    when :aaa
      raise ArgumentError if v == 0
    end
  end
  option_validator :aaa do |v|
    @@validate_count += 1
    raise ArgumentError if v < 0
  end

  def initialize options
    validate_options options
    @options = options
  end

  def num_options bool
    @options.length if bool
  end

  def echo a
    yield a
  end
end

class MyClass3
  include OptionInitializer
  option_initializer :aaa, :bbb, :ccc

  def initialize options
    validate_options options
  end

  def echo a
    yield a
  end
end

class MyClass4
  attr_reader :options

  include OptionInitializer
  option_initializer :two => 2,
                     :two_or_three => 2..3,
                     :yet_two_or_three => 2...4,
                     :b => :block

  def initialize options
    validate_options @options = options
  end
end

class MyClass5
  include OptionInitializer
end

# Excerpt from README
class Person
  include OptionInitializer
  option_initializer! :id, :name, :greetings => :block, :birthday => 1..3
  option_validator :name do |v|
    raise ArgumentError, "invalid name" if v.empty?
  end

  def initialize opts
    validate_options opts
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

    o = MyClass.aaa(1).bbb(2).ccc(3).aaa(4).new(1, 2, :ddd => proc { 4 }) { :y }
    assert_equal 4, o.options[:aaa]
    assert_equal 2, o.options[:bbb]
    assert_equal 3, o.options[:ccc]
    assert_equal 4, o.options[:ddd].call
    assert_equal 1, o.a
    assert_equal 2, o.b
    assert_equal :y, o.y

    assert_instance_of MyClass::OptionInitializing, MyClass.aaa(1)

    assert_raises(ArgumentError) { MyClass.aaa(1) { 1 } }
    assert_raises(ArgumentError) { MyClass.aaa(1, 2) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1, 2, 3) }
  end

  def test_default_1
    MyClass.aaa(1)
    assert_raises(ArgumentError) { MyClass.aaa { } }

    MyClass.bbb(1)
    assert_raises(ArgumentError) { MyClass.bbb { } }
  end

  def test_method_missing
    assert_equal 2, MyClass2.aaa(1).bbb(2).num_options(true)
    assert_equal 2, MyClass2.aaa(1).bbb(2).echo(1) { |a| a * 2 }
    assert_raises(NoMethodError) { MyClass2.aaa(1).bbb(2).echo? }

    assert_raises(NoMethodError) do
      MyClass3.aaa(1).bbb(2).echo(1) { |a| a * 2 }
    end
  end

  def test_validator
    assert_raises(ArgumentError) { MyClass2.aaa(0) }
    assert_raises(ArgumentError) { MyClass2.aaa(-1) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(-1) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(1).new(:aaa => -2) }
    assert_raises(ArgumentError) { MyClass2.aaa(1).aaa(1).new(:aaa => 0) }
    assert_raises(ArgumentError) { MyClass2.new(:aaa => 0) }

    MyClass2.reset_count
    MyClass2.aaa(1)
    assert_equal 2, MyClass2.count

    MyClass2.reset_count
    MyClass2.aaa(1).bbb(2)
    assert_equal 2 + 1, MyClass2.count

    MyClass2.reset_count
    MyClass2.aaa(1).bbb(2).new(:aaa => 3)
    assert_equal 2 + 1 + 2, MyClass2.count

    MyClass2.reset_count
    MyClass2.aaa(1).bbb(2).new
    assert_equal 2 + 1, MyClass2.count

    MyClass2.reset_count
    MyClass2.new :aaa => 1, :bbb => 2
    assert_equal 2 + 1, MyClass2.count

    assert_raises(TypeError) { MyClass2.new 'str' }
  end

  # def assert_raises x, &b
  #   begin
  #     b.call
  #   rescue Exception => e
  #     puts "#{e.class.to_s}: #{e}"
  #     assert e.is_a?(x)
  #   end
  # end

  def test_varargs
    obj = MyClass4.two(1, 2).two_or_three(2, 3, 4).yet_two_or_three(3, 4, 5).b { :r }.new
    assert_equal [1, 2], obj.options[:two]
    assert_equal [2, 3, 4], obj.options[:two_or_three]
    assert_equal [3, 4, 5], obj.options[:yet_two_or_three]
    assert_equal :r, obj.options[:b].call
    assert_raises(ArgumentError) { MyClass4.two(1) }
    assert_raises(ArgumentError) { MyClass4.two(1, 2) { } }
    assert_raises(ArgumentError) { MyClass4.two { } }
    assert_raises(ArgumentError) { MyClass4.two_or_three(1) }
    assert_raises(ArgumentError) { MyClass4.yet_two_or_three(1, 2, 3, 4) }
    assert_raises(ArgumentError) { MyClass4.yet_two_or_three {} }
    assert_raises(TypeError) { MyClass4.b(1) }
    assert_raises(ArgumentError) { MyClass4.b(1) {} }
    assert_raises(ArgumentError) { MyClass4.b(1) {} }

    MyClass4.class_eval do
      option_initializer :b2 => :block
    end
    MyClass4.b2 {}
    assert_raises(TypeError) { MyClass4.b2(5) }

    MyClass4.class_eval do
      option_initializer :b2
    end
    MyClass4.b2(5)
    assert_raises(ArgumentError) { MyClass4.b2 {} }
  end

  def test_varargs_validate_options
    assert_raises(TypeError) { MyClass4.new(:b => 1) }
    assert_raises(ArgumentError) { MyClass4.new(:two_or_three => 1) }
    assert_raises(ArgumentError) { MyClass4.new(:two_or_three => [1]) }
    assert_raises(ArgumentError) { MyClass4.new(:yet_two_or_three => [1]) }
  end

  def test_varargs_def
    assert_raises(NoMethodError) { MyClass5.a(1) }
    MyClass5.class_eval do
      option_initializer :a => 1...4
    end
    MyClass5.a(1)

    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer :b => 0 } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer :b => 3.14 } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer :b => [1] } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer :b => 0..3 } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer 3.14 } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer 3.14 => nil } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_initializer :b => :block? } }
  end

  def test_validator_block_arity
    MyClass5.class_eval { option_validator { |k, v| } }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_validator { |v| } } }
    MyClass5.class_eval { option_validator :aaa do |v| end }
    assert_raises(ArgumentError) { MyClass5.class_eval { option_validator :aaa do |k, v| end } }
  end

  def test_readme
    john = Person.name('John Doe').birthday(1990, 1, 1).
                  greetings { |name| "Hi, I'm #{name}!" }.id(1000).new
    john = Person.new :id => 1000, :name => 'John Doe',
                      :birthday => [1990, 1, 1],
                      :greetings => proc { |name| "Hi, I'm #{name}!" }
    Person.name('John Doe').birthday(1990, 1, 1).
           greetings { |name| "Hi, I'm #{name}!" }.id(1000).say_hello
  end
end

