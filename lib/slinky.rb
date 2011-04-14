ROOT = File.expand_path(File.dirname(__FILE__))

require 'eventmachine'
require 'evma_httpserver'
require 'uri'
require 'tempfile'
require 'rainbow'
require 'rbtrace'

require "#{ROOT}/slinky/em-popen3"
require "#{ROOT}/slinky/compiled_file"
require "#{ROOT}/slinky/server"
require "#{ROOT}/slinky/runner"

# load compilers
Dir.glob("#{ROOT}/slinky/compilers/*.rb").each{|compiler|
	begin
		require compiler
	rescue
		puts "Failed to load #{compiler}: #{$!}"
	rescue LoadError
		puts "Failed to load #{compiler}: syntax error"
	end
}
