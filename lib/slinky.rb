require 'em-proxy'
require 'em-websocket'
require 'eventmachine'
require 'evma_httpserver'
require 'listen'
require 'mime/types'
require 'multi_json'
require 'optparse'
require 'rainbow'
require 'tempfile'
require 'tsort'
require 'uglifier'
require 'uri'
require 'uri'
require 'yaml'

require "slinky/em-popen3"
require "slinky/errors"
require "slinky/compilers"
require "slinky/config_reader"
require "slinky/graph"
require "slinky/manifest"
require "slinky/compiled_file"
require "slinky/proxy_server"
require "slinky/server"
require "slinky/runner"
require "slinky/builder"
require "slinky/listener"
require "slinky/live_reload"

begin
  require "transitive_closure"
rescue LoadError
  puts "Using pure Ruby implementation of Slinky::all_paths_costs"
end

# load compilers
root = File.expand_path(File.dirname(__FILE__))
Dir.glob("#{root}/slinky/compilers/*.rb").each{|compiler|
  begin
    require compiler
  rescue
    puts "Failed to load #{compiler}: #{$!}"
  rescue LoadError
    puts "Failed to load #{compiler}: syntax error"
  end
}
