# Gorbe

Gorbe is a Ruby to Go source code compiler.
Gorbe uses [grumpy](https://github.com/google/grumpy) for the runtime but itself also has some extension for the Ruby support.

<!--
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gorbe'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gorbe
-->

## Usage

### Compile Ruby to Go source code

```bash
$ cd bin
$ echo "p(1 + 1) unless false" | ./gorbec
```

### Compile Ruby to Go source code and immediately run it on Grumpy

1. Clone [grumpy](https://github.com/google/grumpy)
2. Set paths for grumpy 
    ```bash
    $ cd grumpy
    $ make
    $ export PATH=$PWD/build/bin:$PATH
    $ export GOPATH=$PWD/build
    $ export PYTHONPATH=$PWD/build/lib/python2.7/site-packages
    ```
3. Set paths for gorbe
    ```bash
    $ cd gorbe
    $ export GOPATH=$GOPATH:$PWD/go
    ```
4. Execute the following command
    ```bash
    $ rake init
    ```
5. Run
    ```bash
    $ echo "p(1 + 1) unless false" | rake run
    ```
    
### Run test
    
```bash
$ rake test
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
<!--
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
-->

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/okamotoyuki/gorbe.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
