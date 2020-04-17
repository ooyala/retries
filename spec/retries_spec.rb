# frozen_string_literal: true

require 'timeout'

require_relative '../lib/retries'

class CustomErrorA < RuntimeError; end
class CustomErrorB < RuntimeError; end

describe Retries do
  subject(:run) { described_class.run(options, &block) }

  let(:options) { {} }
  let(:block) { proc {} }

  attr_reader :tries

  before do
    @tries = 0
    described_class.options.merge!(
      sleep_enabled: true, base_sleep_seconds: 0, max_sleep_seconds: 0
    )
  end

  describe 'retries until successful' do
    let(:max_tries) { 4 }
    let(:options) { { max_tries: max_tries, rescue: CustomErrorA } }

    let(:block) do
      proc do |attempt|
        @tries += 1
        # Verify that the attempt number passed in is accurate
        expect(attempt).to eq tries
        raise CustomErrorA if tries < max_tries

        'done'
      end
    end

    it { is_expected.to eq 'done' }

    describe 'number of tries' do
      subject { tries }

      before do
        run
      end

      it { is_expected.to eq max_tries }
    end
  end

  describe 're-raise after max tries' do
    let(:options) { { rescue: CustomErrorA } }
    let(:block) do
      proc { raise CustomErrorA }
    end

    it { expect { run }.to raise_error CustomErrorA }
  end

  describe 'raising error if `:max_tries` is equal to zero' do
    let(:options) { { max_tries: 0 } }

    it do
      expect { run }.to raise_error(
        ArgumentError, ':max_tries must be greater than 0'
      )
    end
  end

  describe 'raising error if `:max_tries` is less than zero' do
    let(:options) { { max_tries: -1 } }

    it do
      expect { run }.to raise_error(
        ArgumentError, ':max_tries must be greater than 0'
      )
    end
  end

  describe 'rescuing `StandardError` if no `:rescue` is specified' do
    subject { tries }

    let(:number_of_tries) { 2 }

    let(:block) do
      proc do
        @tries += 1
        raise CustomErrorA, 'boom' if tries < number_of_tries
      end
    end

    before do
      run
    end

    it { is_expected.to eq number_of_tries }
  end

  describe 'immediately raising any exception not specified by `:rescue`' do
    let(:options) { { rescue: CustomErrorB } }

    let(:block) do
      proc do
        @tries += 1
        raise CustomErrorA
      end
    end

    it { expect { run }.to raise_error CustomErrorA }

    describe 'number of tries' do
      subject { tries }

      before do
        begin
          run
        rescue CustomErrorA
          # Just as expected
        end
      end

      it { is_expected.to eq 1 }
    end
  end

  describe 'catching any of multiple exceptions specified by rescue' do
    let(:options) { { max_tries: 3, rescue: [CustomErrorA, CustomErrorB] } }

    let(:block) do
      proc do |attempt|
        raise CustomErrorA if attempt.zero?
        raise CustomErrorB if attempt == 1

        'done'
      end
    end

    it { is_expected.to eq 'done' }
  end

  describe 'running handler with the expected args' do
    attr_reader :exception_handler_run_times

    let(:handler) do
      @exception_handler_run_times = 0
      proc do |exception, attempt_number|
        @exception_handler_run_times += 1
        # Check that the handler is passed the proper exception
        # and attempt number
        expect(attempt_number).to eq exception_handler_run_times
        expect(exception).to be_instance_of CustomErrorA
      end
    end

    let(:max_tries) { 4 }

    let(:options) do
      { max_tries: max_tries, handler: handler, rescue: CustomErrorA }
    end

    let(:block) do
      proc do
        @tries += 1
        raise CustomErrorA if tries < max_tries
      end
    end

    before do
      run
    end

    describe 'number of tries' do
      subject { tries }

      it { is_expected.to eq max_tries }
    end

    describe 'number of exception handler runs' do
      subject { exception_handler_run_times }

      it { is_expected.to eq max_tries - 1 }
    end
  end

  describe 'passing total time to handler upon each handled exception' do
    subject(:total_delays_equal) { [] }

    before do
      described_class.options[:sleep_enabled] = false
      @fake_time = -10

      allow(Time).to receive(:now) { @fake_time += 10 }

      run
    end

    attr_reader :fake_time

    let(:handler) do
      proc do |_exception, _attempt_number, total_delay|
        # Check that the handler is passed the proper total delay time
        total_delays_equal << (total_delay == fake_time)
      end
    end

    let(:max_tries) { 3 }

    let(:options) do
      {
        sleep_enabled: false, max_tries: max_tries, handler: handler,
        rescue: CustomErrorA
      }
    end

    let(:block) do
      proc do
        @tries += 1
        raise CustomErrorA if tries < max_tries
      end
    end

    it { is_expected.to eq [true] * (max_tries - 1) }
  end

  context 'when `:sleep_enabled` is false' do
    subject(:run_with_timeout) { Timeout.timeout(2) { run } }

    before do
      described_class.options[:sleep_enabled] = false
    end

    let(:options) do
      { max_tries: 10, base_sleep_seconds: 100, max_sleep_seconds: 10_000 }
    end

    let(:block) do
      proc do
        raise 'blah'
      end
    end

    # If we get a Timeout::Error, this won't pass.
    it { expect { run_with_timeout }.to raise_error RuntimeError, 'blah' }
  end

  context 'when `:base_sleep_seconds` is greater than `:max_sleep_seconds`' do
    let(:options) { { base_sleep_seconds: 2, max_sleep_seconds: 1 } }

    it do
      expect { run }.to raise_error(
        ArgumentError,
        ':base_sleep_seconds cannot be greater than :max_sleep_seconds'
      )
    end
  end

  context 'when block not passed' do
    let(:block) { nil }

    it do
      expect { run }.to raise_error(
        ArgumentError, 'tried to create Retries object without a block'
      )
    end
  end
end
