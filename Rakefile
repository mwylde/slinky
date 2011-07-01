require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "slinky"
  gem.homepage = "http://github.com/mwylde/slinky"
  gem.license = "MIT"
  gem.summary = %Q{Static file server for javascript apps}
  gem.description = %Q{A static file server for rich javascript apps that automatically compiles SASS, HAML, CoffeeScript and more}
  gem.email = "mwylde@wesleyan.edu"
  gem.authors = ["mwylde"]
end
Jeweler::RubygemsDotOrgTasks.new

namespace :cover_me do
  task :report do
    require 'cover_me'
    # CoverMe.config do |c|
    #   # where is your project's root:
    #   c.project.root = Dir.pwd
      
    #   # what files are you interested in coverage for:
    #   c.file_pattern = /(#{CoverMe.config.project.root}\/lib\/.+\.rb)/i
    # end
    CoverMe.complete!
  end
end

# task :spec do
#   Rake::Task['cover_me:report'].invoke
# end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end



task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
