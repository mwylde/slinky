ROOT = File.expand_path(File.dirname(__FILE__))

require 'eventmachine'
require 'evma_httpserver'
require 'uri'

require "#{ROOT}/static-runner/em-popen3"
require "#{ROOT}/static-runner/server"
require "#{ROOT}/static-runner/runner"

Dir.glob("#{File.dirname(__FILE__)}/static-runner/compilers/*.rb").each{|compiler|
	begin
		require compiler
	rescue
		puts "Failed to load #{compiler}: #{$!}"
	rescue LoadError
		puts "Failed to load #{compiler}: syntax error"
	end
}
