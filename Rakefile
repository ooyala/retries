# frozen_string_literal: true

require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  namespace :test do
    RSpec::Core::RakeTask.new(:units)
  end

  task test: ['test:units']

  task default: :test
rescue LoadError
  puts 'No RSpec available'
end
