require "scope"
require "minitest/autorun"

$:.unshift File.join(File.dirname(__FILE__), "../lib")
require "retries"

class CustomErrorA < RuntimeError; end
class CustomErrorB < RuntimeError; end

class RetriesTest < Scope::TestCase
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
      with_retries(:max_tries => 4, :base_sleep_seconds => 0, :max_sleep_seconds => 0, :handler => handler,
                   :rescue => CustomErrorA) do
        tries += 1
        raise CustomErrorA.new if tries < 4
      end
      assert_equal 4, tries
      assert_equal 3, exception_handler_run_times
    end
  end
end
