# option_initializer

Provides syntactic sugar for constructing an object with method chaining.

## Installation

```
gem install option_initializer
```

## Usage

```ruby
require 'option_initializer'

class Person
  include OptionInitializable
  option_initializer :name, :age, :id

  def initialize opts
    @options = opts
  end

  def say_hello
    puts "Hi, I'm #{@options[:name]}!"
  end
end

# Then
john = Person.name('John Doe').age(19).id(1000).new

# becomes equivalent to
john = Person.new :id => 1000, :name => 'John Doe', :age => 19

# Method call shortcut
Person.name('John Doe').age(19).id(1000).say_hello
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
