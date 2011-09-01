ROOT = File.expand_path(File.dirname(__FILE__))
require "bundler/setup"
require 'uri'
require 'yaml'
require 'eventmachine'
require 'em-proxy'
require 'evma_httpserver'
require 'uri'
require 'tempfile'
require 'rainbow'
require 'optparse'
require 'mime/types'
require 'yui/compressor'

require "#{ROOT}/slinky/em-popen3"
require "#{ROOT}/slinky/compilers"
require "#{ROOT}/slinky/config_reader"
require "#{ROOT}/slinky/manifest"
require "#{ROOT}/slinky/compiled_file"
require "#{ROOT}/slinky/proxy_server"
require "#{ROOT}/slinky/server"
require "#{ROOT}/slinky/runner"
require "#{ROOT}/slinky/builder"

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

# Without this monkeypatch data uris in CSS cause compression to fail
class YUI::Compressor
  def command
    @command.insert 1, "-Xss8m"
    @command.map { |word| Shellwords.escape(word) }.join(" ")
  end
end
