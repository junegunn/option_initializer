$VERBOSE = true

require 'rubygems'
require 'minitest/autorun'
require 'option_initializer'

class MyClass
  include OptionInitializer
  option_initializer :aaa, :bbb
  option_initializer :ccc

  attr_reader :a, :b, :options

  def initialize a, b, opts
    @a = a
    @b = b
    @options = opts
  end
end

class MyClass2
  include OptionInitializer
  option_initializer :aaa, :bbb, :ccc

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

class TestOptionInitializer < MiniTest::Unit::TestCase
  def test_oi
    o = MyClass.aaa(1).bbb(2).ccc(3).new(1, 2)
    assert_equal 1, o.options[:aaa]
    assert_equal 2, o.options[:bbb]
    assert_equal 3, o.options[:ccc]
    assert_equal 1, o.a
    assert_equal 2, o.b

    o = MyClass.aaa(1).bbb(2).ccc(3).aaa(4).new(1, 2, :ddd => 4)
    assert_equal 4, o.options[:aaa]
    assert_equal 2, o.options[:bbb]
    assert_equal 3, o.options[:ccc]
    assert_equal 4, o.options[:ddd]
    assert_equal 1, o.a
    assert_equal 2, o.b

    assert_instance_of MyClass::OptionInitializing, MyClass.aaa(1)

    assert_raises(ArgumentError) { MyClass.aaa(1, 2) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1) }
    assert_raises(ArgumentError) { MyClass.aaa(1).new(1, 2, 3) }
  end

  def test_method_missing
    assert_equal 2, MyClass2.aaa(1).bbb(2).num_options(true)
    assert_equal 2, MyClass2.aaa(1).bbb(2).echo(1) { |a| a * 2 }
  end
end

