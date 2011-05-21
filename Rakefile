require 'bundler'
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :build do
  system "gem build closure_tree.gemspec"
end

task :release => :build do
  system "gem push closure_tree-#{ClosureTree::VERSION}.gem"
end

#require 'rdoc/task'
#desc 'Generate documentation for the closure-tree plugin.'
#Rake::RDocTask.new(:rdoc) do |rdoc|
#  rdoc.rdoc_dir = 'rdoc'
#  rdoc.title    = 'ClosureTree'
#  rdoc.options << '--line-numbers' << '--inline-source'
#  # rdoc.rdoc_files.include('README')
#  rdoc.rdoc_files.include('lib/**/*.rb')
#end
