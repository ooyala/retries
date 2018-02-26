# frozen_string_literal: true

# Class for `VERSION` constant and `sleep_enabled` accessor
class Retries
  VERSION = '1.0.0'

  class << self
    # You can use this to turn off all sleeping in with_retries.
    # This can be useful in tests. Defaults to `true`.
    attr_accessor :sleep_enabled
  end
end

Retries.sleep_enabled = true

# Add custom method `with_retries` to `Kernel` module
module Kernel
  # Runs the supplied code block an retries with an exponential backoff.
  #
  # @param [Hash] options the retry options.
  # @option options [Fixnum] :max_tries (3)
  #   The maximum number of times to run the block.
  # @option options [Float] :base_sleep_seconds (0.5)
  #   The starting delay between retries.
  # @option options [Float] :max_sleep_seconds (1.0)
  #   The maximum to which to expand the delay between retries.
  # @option options [Proc] :handler (nil)
  #   If not `nil`, a `Proc` that will be called for each retry.
  #   It will be passed three arguments, `exception` (the rescued exception),
  #   `attempt_number`, and `total_delay`
  #   (seconds since start of first attempt).
  # @option options [Exception, <Exception>] :rescue (StandardError)
  #   This may be a specific exception class to rescue or an array of classes.
  # @yield [attempt_number]
  #   The (required) block to be executed,
  #   which is passed the attempt number as a parameter.
  def with_retries(options = {}, &_block)
    # Check the options and set defaults
    max_tries = options.fetch(:max_tries, 3)
    unless max_tries.positive?
      raise ArgumentError, ':max_tries must be greater than 0'
    end

    base_sleep_seconds = options.fetch(:base_sleep_seconds, 0.5)
    max_sleep_seconds = options.fetch(:max_sleep_seconds, 1.0)
    if base_sleep_seconds > max_sleep_seconds
      raise(
        ArgumentError,
        ':base_sleep_seconds cannot be greater than :max_sleep_seconds'
      )
    end
    handler = options[:handler]
    exception_types_to_rescue = Array(options.fetch(:rescue, StandardError))
    unless block_given?
      raise ArgumentError, 'with_retries must be passed a block'
    end

    # Let's do this thing
    attempts = 0
    start_time = Time.now
    begin
      attempts += 1
      yield(attempts)
    rescue *exception_types_to_rescue => e
      raise e if attempts >= max_tries

      handler&.call(e, attempts, Time.now - start_time)
      # Don't sleep at all if sleeping is disabled (used in testing).
      if Retries.sleep_enabled
        # The sleep time is an exponentially-increasing function
        # of base_sleep_seconds. But, it never exceeds max_sleep_seconds.
        sleep_seconds = [
          base_sleep_seconds * (2**(attempts - 1)),
          max_sleep_seconds
        ].min
        # Randomize to a random value in the range
        # sleep_seconds/2 .. sleep_seconds
        sleep_seconds *= (0.5 * (1 + rand))
        # But never sleep less than base_sleep_seconds
        sleep_seconds = [base_sleep_seconds, sleep_seconds].max
        sleep sleep_seconds
      end
      retry
    end
  end
end
