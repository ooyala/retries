require "scope"
require "minitest/autorun"
require "timeout"
require "rr"

$:.unshift File.join(File.dirname(__FILE__), "../lib")
require "retries"

module Scope
  class TestCase
    include RR::Adapters::MiniTest
  end
end

class CustomErrorA < RuntimeError; end
class CustomErrorB < RuntimeError; end

class RetriesTest < Scope::TestCase
  setup do
    Retries.sleep_enabled = true
  end

  context "with_retries" do
    should "retry until successful" do
      tries = 0
      result = with_retries(:max_tries => 4, :base_sleep_seconds => 0, :max_sleep_seconds => 0,
                            :rescue => CustomErrorA) do |attempt|
        tries += 1
        # Verify that the attempt number passed in is accurate
        assert_equal tries, attempt
        raise CustomErrorA.new if tries < 4
        "done"
      end
      assert_equal "done", result
      assert_equal 4, tries
    end

    should "re-raise after :max_tries" do
      assert_raises(CustomErrorA) do
        with_retries(:base_sleep_seconds => 0, :max_sleep_seconds => 0, :rescue => CustomErrorA) do
          raise CustomErrorA.new
        end
      end
    end

    should "rescue StandardError if no :rescue is specified" do
      tries = 0
      class MyError < StandardError; end
      with_retries(:base_sleep_seconds => 0, :max_sleep_seconds => 0) do
        tries += 1
        if tries < 2
          raise MyError, "boom"
        end
      end
      assert_equal 2, tries
    end

    should "immediately raise any exception not specified by :rescue" do
      tries = 0
      assert_raises(CustomErrorA) do
        with_retries(:base_sleep_seconds => 0, :max_sleep_seconds => 0, :rescue => CustomErrorB) do
          tries += 1
          raise CustomErrorA.new
        end
      end
      assert_equal 1, tries
    end

    should "allow for catching any of an array of exceptions specified by :rescue" do
      result = with_retries(:max_tries => 3, :base_sleep_seconds => 0, :max_sleep_seconds => 0,
                   :rescue => [CustomErrorA, CustomErrorB]) do |attempt|
        raise CustomErrorA.new if attempt == 0
        raise CustomErrorB.new if attempt == 1
        "done"
      end
      assert_equal "done", result
    end

    should "run :handler with the expected arguments upon each handled exception" do
      exception_handler_run_times = 0
      tries = 0
      handler = Proc.new do |exception, attempt_number|
        exception_handler_run_times += 1
        # Check that the handler is passed the proper exception and attempt number
        assert_equal exception_handler_run_times, attempt_number
        assert exception.is_a?(CustomErrorA)
      end
      with_retries(:max_tries => 4, :base_sleep_seconds => 0, :max_sleep_seconds => 0,
                   :handler => handler, :rescue => CustomErrorA) do
        tries += 1
        raise CustomErrorA.new if tries < 4
      end
      assert_equal 4, tries
      assert_equal 3, exception_handler_run_times
    end

    should "pass total elapsed time to :handler upon each handled exception" do
      Retries.sleep_enabled = false
      fake_time = -10
      stub(Time).now { fake_time += 10 }
      handler = Proc.new do |exception, attempt_number, total_delay|
        # Check that the handler is passed the proper total delay time
        assert_equal fake_time, total_delay
      end
      tries = 0
      with_retries(:max_tries => 3, :handler => handler, :rescue => CustomErrorA) do
        tries += 1
        raise CustomErrorA.new if tries < 3
      end
    end

    should "not sleep if Retries.sleep_enabled is false" do
      Retries.sleep_enabled = false
      assert_raises(RuntimeError) do # If we get a Timeout::Error, this won't pass.
        Timeout.timeout(2) do
          with_retries(:max_tries => 10, :base_sleep_seconds => 100, :max_sleep_seconds => 10000) do
            raise "blah"
          end
        end
      end
    end
  end
end
