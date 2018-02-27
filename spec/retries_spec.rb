# frozen_string_literal: true

require 'timeout'

require_relative '../lib/retries'

class CustomErrorA < RuntimeError; end
class CustomErrorB < RuntimeError; end

describe Retries do
  before do
    Retries.options.merge!(
      sleep_enabled: true, base_sleep_seconds: 0, max_sleep_seconds: 0
    )
  end

  it 'retries until successful' do
    tries = 0
    result = Retries.run(max_tries: 4, rescue: CustomErrorA) do |attempt|
      tries += 1
      # Verify that the attempt number passed in is accurate
      expect(attempt).to eq tries
      raise CustomErrorA if tries < 4

      'done'
    end
    expect(result).to eq 'done'
    expect(tries).to eq 4
  end

  it 're-raises after max tries' do
    expect do
      Retries.run(rescue: CustomErrorA) do
        raise CustomErrorA
      end
    end
      .to raise_error CustomErrorA
  end

  it 'raises error if :max_tries is equal to 0' do
    expect do
      Retries.run(max_tries: 0) {}
    end
      .to raise_error ArgumentError, ':max_tries must be greater than 0'
  end

  it 'raises error if :max_tries is less than 0' do
    expect do
      Retries.run(max_tries: -1) {}
    end
      .to raise_error ArgumentError, ':max_tries must be greater than 0'
  end

  it 'rescue standarderror if no rescue is specified' do
    tries = 0
    Retries.run do
      tries += 1
      raise CustomErrorA, 'boom' if tries < 2
    end
    expect(tries).to eq 2
  end

  it 'immediately raise any exception not specified by rescue' do
    tries = 0
    expect do
      Retries.run(rescue: CustomErrorB) do
        tries += 1
        raise CustomErrorA
      end
    end
      .to raise_error CustomErrorA
    expect(tries).to eq 1
  end

  it 'allow for catching any of multiple exceptions specified by rescue' do
    result = Retries.run(
      max_tries: 3, rescue: [CustomErrorA, CustomErrorB]
    ) do |attempt|
      raise CustomErrorA if attempt.zero?
      raise CustomErrorB if attempt == 1

      'done'
    end
    expect(result).to eq 'done'
  end

  it 'run handler with the expected args upon each handled exception' do
    exception_handler_run_times = 0
    tries = 0
    handler = proc do |exception, attempt_number|
      exception_handler_run_times += 1
      # Check that the handler is passed the proper exception and attempt number
      expect(attempt_number).to eq exception_handler_run_times
      expect(exception).to be_instance_of CustomErrorA
    end
    Retries.run(max_tries: 4, handler: handler, rescue: CustomErrorA) do
      tries += 1
      raise CustomErrorA if tries < 4
    end
    expect(tries).to eq 4
    expect(exception_handler_run_times).to eq 3
  end

  it 'pass total elapsed time to handler upon each handled exception' do
    Retries.options[:sleep_enabled] = false
    fake_time = -10

    allow(Time).to receive(:now) { fake_time += 10 }

    handler = proc do |_exception, _attempt_number, total_delay|
      # Check that the handler is passed the proper total delay time
      expect(total_delay).to eq fake_time
    end

    tries = 0

    Retries.run(
      sleep_enabled: false, max_tries: 3, handler: handler,
      rescue: CustomErrorA
    ) do
      tries += 1
      raise CustomErrorA if tries < 3
    end
  end

  it 'not sleep if sleep enabled is false' do
    Retries.options[:sleep_enabled] = false
    # If we get a Timeout::Error, this won't pass.
    expect do
      Timeout.timeout(2) do
        Retries.run(
          sleep_enabled: false, max_tries: 10,
          base_sleep_seconds: 100, max_sleep_seconds: 10_000
        ) do
          raise 'blah'
        end
      end
    end
      .to raise_error RuntimeError, 'blah'
  end

  it 'raises error if :base_sleep_seconds is greater than :max_sleep_seconds' do
    expect do
      Retries.run(base_sleep_seconds: 2, max_sleep_seconds: 1) {}
    end
      .to raise_error(
        ArgumentError,
        ':base_sleep_seconds cannot be greater than :max_sleep_seconds'
      )
  end

  it 'raises error if no block passed' do
    expect do
      Retries.run
    end
      .to raise_error(
        ArgumentError, 'tried to create Retries object without a block'
      )
  end
end
