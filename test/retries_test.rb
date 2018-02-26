require 'minitest/autorun'
require 'rr'
require 'timeout'

require_relative '../lib/retries'

class CustomErrorA < RuntimeError; end
class CustomErrorB < RuntimeError; end

class RetriesTest < Minitest::Test
  def setup
    Retries.sleep_enabled = true
  end

  def test_retries_until_successful
    tries = 0
    result = with_retries(
      max_tries: 4, base_sleep_seconds: 0, max_sleep_seconds: 0,
      rescue: CustomErrorA
    ) do |attempt|
      tries += 1
      # Verify that the attempt number passed in is accurate
      assert_equal tries, attempt
      raise CustomErrorA if tries < 4
      'done'
    end
    assert_equal 'done', result
    assert_equal 4, tries
  end

  def test_re_raises_after_max_tries
    assert_raises(CustomErrorA) do
      with_retries(
        base_sleep_seconds: 0, max_sleep_seconds: 0, rescue: CustomErrorA
      ) do
        raise CustomErrorA
      end
    end
  end

  def test_rescue_standarderror_if_no_rescue_is_specified
    tries = 0
    with_retries(base_sleep_seconds: 0, max_sleep_seconds: 0) do
      tries += 1
      raise CustomErrorA, 'boom' if tries < 2
    end
    assert_equal 2, tries
  end

  def test_immediately_raise_any_exception_not_specified_by_rescue
    tries = 0
    assert_raises(CustomErrorA) do
      with_retries(
        base_sleep_seconds: 0, max_sleep_seconds: 0, rescue: CustomErrorB
      ) do
        tries += 1
        raise CustomErrorA
      end
    end
    assert_equal 1, tries
  end

  def test_allow_for_catching_any_of_multiple_exceptions_specified_by_rescue
    result = with_retries(
      max_tries: 3, base_sleep_seconds: 0, max_sleep_seconds: 0,
      rescue: [CustomErrorA, CustomErrorB]
    ) do |attempt|
      raise CustomErrorA if attempt.zero?
      raise CustomErrorB if attempt == 1
      'done'
    end
    assert_equal 'done', result
  end

  def test_run_handler_with_the_expected_args_upon_each_handled_exception
    exception_handler_run_times = 0
    tries = 0
    handler = proc do |exception, attempt_number|
      exception_handler_run_times += 1
      # Check that the handler is passed the proper exception and attempt number
      assert_equal exception_handler_run_times, attempt_number
      assert exception.is_a?(CustomErrorA)
    end
    with_retries(
      max_tries: 4, base_sleep_seconds: 0, max_sleep_seconds: 0,
      handler: handler, rescue: CustomErrorA
    ) do
      tries += 1
      raise CustomErrorA if tries < 4
    end
    assert_equal 4, tries
    assert_equal 3, exception_handler_run_times
  end

  def test_pass_total_elapsed_time_to_handler_upon_each_handled_exception
    Retries.sleep_enabled = false
    fake_time = -10
    stub(Time).now { fake_time += 10 }
    handler = proc do |_exception, _attempt_number, total_delay|
      # Check that the handler is passed the proper total delay time
      assert_equal fake_time, total_delay
    end
    tries = 0
    with_retries(max_tries: 3, handler: handler, rescue: CustomErrorA) do
      tries += 1
      raise CustomErrorA if tries < 3
    end
  end

  def test_not_sleep_if_sleep_enabled_is_false
    Retries.sleep_enabled = false
    # If we get a Timeout::Error, this won't pass.
    assert_raises(RuntimeError) do
      Timeout.timeout(2) do
        with_retries(
          max_tries: 10, base_sleep_seconds: 100, max_sleep_seconds: 10_000
        ) do
          raise 'blah'
        end
      end
    end
  end
end
