# frozen_string_literal: true

# Class for retries running
class Retries
  VERSION = '1.0.0'

  class << self
    # Global (default) options. Can be changed via `#[]` or `#merge!`.
    # @return [Hash] options
    # @example Change a single value
    #   Retries.options[:sleep_enabled] = false
    # @example Change multiple values
    #   Retries.options.merge! max_tries: 50, max_sleep_seconds: 15
    def options
      @options ||= {
        sleep_enabled: true,
        max_tries: 3,
        base_sleep_seconds: 0.5,
        max_sleep_seconds: 1.0,
        rescue: StandardError
      }
    end

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
    def run(options = {}, &block)
      new(options, &block).run
    end
  end

  REQUIRED_SIMPLE_OPTIONS = %i[
    sleep_enabled max_tries base_sleep_seconds max_sleep_seconds
  ].freeze

  private_constant :REQUIRED_SIMPLE_OPTIONS

  def initialize(options = {}, &block)
    options = self.class.options.merge options

    REQUIRED_SIMPLE_OPTIONS.each do |option_name|
      instance_variable_set :"@#{option_name}", options.fetch(option_name)
    end

    @handler = options[:handler]

    @exception_types_to_rescue = Array(options.fetch(:rescue))

    @block = block

    validate
  end

  def run
    # Let's do this thing
    @attempts = 0
    @start_time = Time.now
    try
  end

  private

  def validate
    unless @max_tries.positive?
      raise ArgumentError, ':max_tries must be greater than 0'
    end

    if @base_sleep_seconds > @max_sleep_seconds
      raise ArgumentError,
        ':base_sleep_seconds cannot be greater than :max_sleep_seconds'
    end

    return true if @block

    raise ArgumentError, 'tried to create Retries object without a block'
  end

  def try
    @attempts += 1
    @block.call(@attempts)
  rescue *@exception_types_to_rescue => e
    raise e if @attempts >= @max_tries

    @handler&.call(e, @attempts, Time.now - @start_time)
    # Don't sleep at all if sleeping is disabled (used in testing).
    sleep sleep_seconds if @sleep_enabled
    retry
  end

  def sleep_seconds
    # The sleep time is an exponentially-increasing function
    # of base_sleep_seconds. But, it never exceeds max_sleep_seconds.
    sleep_seconds = [
      @base_sleep_seconds * (2**(@attempts - 1)),
      @max_sleep_seconds
    ].min
    # Randomize to a random value in the range
    # sleep_seconds/2 .. sleep_seconds
    sleep_seconds *= (0.5 * (1 + rand))
    # But never sleep less than base_sleep_seconds
    [@base_sleep_seconds, sleep_seconds].max
  end
end
