# frozen_string_literal: true

require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new

  task default: :spec
rescue LoadError
  puts 'No RSpec available'
end
