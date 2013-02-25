# option_initializer

Provides syntactic sugar for constructing objects with method chaining.

## Installation

```
gem install option_initializer
```

## Usage

```ruby
require 'option_initializer'

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

# Then
john = Person.
         name('John Doe').
         age(19).
         greetings { |name| "Hi, I'm #{name}!" }.
         id(1000).
         new

# becomes equivalent to
john = Person.new(
         :id => 1000,
         :name => 'John Doe',
         :age => 19,
         :greetings => proc { |name| "Hi, I'm #{name}!" }
       )

# Method call shortcut
Person.
  name('John Doe').
  age(19).
  greetings { |name| "Hi, I'm #{name}!" }.
  id(1000).
  say_hello
```

