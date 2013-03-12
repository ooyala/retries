# Retries

Retries is a gem that provides a single function, `with_retries`, to evaluate a block with randomized,
truncated, exponential backoff.

There are similar projects out there (see [retry_block](https://github.com/afazio/retry_block) and
[retry_this](https://bitbucket.org/amanking/retry_this/wiki/Home), for example) but these will require you to
implement the backoff scheme yourself. If you don't need randomized exponential backoff, you should check out
those gems.

## Installation

You can get the gem with `gem install retries` or simply add `gem "retries"` to your Gemfile if you're using
bundler.

## Usage

Suppose we have some task we are trying to perform: `do_the_thing`. This might be a call to a third-party API
or a flaky service. Here's how you can try it three times before failing:

``` ruby
require "retries"
with_retries(:max_tries => 3) { do_the_thing }
```

The block is passed a single parameter, `attempt_number`, which is the number of attempts that have been made
(starting at 1):

``` ruby
with_retries(:max_tries => 3) do |attempt_number|
  puts "Trying to do the thing: attempt #{attempt_number}"
  do_the_thing
end
```

### Custom exceptions

By default `with_retries` rescues instances of `StandardError`. You'll likely want to make this more specific
to your use case. You may provide an exception class or an array of classes:

``` ruby
with_retries(:max_tries => 3, :rescue => RestClient::Exception) { do_the_thing }
with_retries(:max_tries => 3, :rescue => [RestClient::Unauthorized, RestClient::RequestFailed]) do
  do_the_thing
end
```

### Handlers

`with_retries` allows you to pass a custom handler that will be called each time before the block is retried.
The handler will be called with three arguments: `exception` (the rescued exception), `attempt_number` (the
number of attempts that have been made thus far), and `total_delay` (the number of seconds since the start
of the time the block was first attempted, including all retries).

``` ruby
handler = Proc.new do |exception, attempt_number, total_delay|
  puts "Handler saw a #{exception.class}; retry attempt #{attempt_number}; #{total_delay} seconds have passed."
end
with_retries(:max_tries => 5, :handler => handler, :rescue => [RuntimeError, ZeroDivisionError]) do |attempt|
  (1 / 0) if attempt == 3
  raise "hey!" if attempt < 5
end
```

This will print something like:

```
Handler saw a RuntimeError; retry attempt 1; 2.9e-05 seconds have passed.
Handler saw a RuntimeError; retry attempt 2; 0.501176 seconds have passed.
Handler saw a ZeroDivisionError; retry attempt 3; 1.129921 seconds have passed.
Handler saw a RuntimeError; retry attempt 4; 1.886828 seconds have passed.
```

### Delay parameters

By default, `with_retries` will wait about a half second between the first and second attempts, and then the
delay time will increase exponentially between attempts (but stay at no more than 1 second). The delays are
perturbed randomly. You can control the parameters via the two options `:base_sleep_seconds` and
`:max_sleep_seconds`. For instance, you can start the delay at 100ms and go up to a maximum of about 2
seconds:

``` ruby
with_retries(:max_tries => 10, :base_sleep_seconds => 0.1, :max_sleep_seconds => 2.0) { do_the_thing }
```

### Testing

In tests, you may wish to test that retries are being performed without any delay for sleeping:

``` ruby
Retries.sleep_enabled = false
with_retries(:max_tries => 100) { raise "Boo!" } # Now this fails fast
```

Of course, this will mask any errors to the `:base_sleep_seconds` and `:max_sleep_seconds` parameters, so use
with caution.

## Issues

File tickets here on Github.

## Development

To run the tests: first clone the repo, then

    $ bundle install
    $ bundle exec rake test

## Authors

* Harry Robertson
* Caleb Spare

## License

Retries is released under the [MIT License](http://opensource.org/licenses/mit-license.php/).
