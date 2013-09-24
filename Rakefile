#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Mor::Application.load_tasks

task :default => [:test]

Rake::Task["db:drop"].clear
task 'db:drop' do
  puts "You were just prevented from dropping your DB!"
end

Rake::Task["test"].clear
task 'test' do
  puts "You were just prevented from dropping your DB!"
end
