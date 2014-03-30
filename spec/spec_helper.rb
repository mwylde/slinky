$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'bundler/setup'
require 'rspec'
require 'slinky'
require 'fakefs/safe'
require 'fileutils'
require 'open-uri'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

module Slinky
  # The coffee script compiler doesn't work under FakeFS
  module CoffeeCompiler
    def CoffeeCompiler::compile s, file
      FakeFS.deactivate!
      o = CoffeeScript::compile(s)
      FakeFS.activate!
      o
    end
  end

  # This is necessary because require doesn't work with FakeFS
  class Compilers
    class << self
      alias :get_old_cfile :get_cfile
      def get_cfile *args
        FakeFS.deactivate!
        cfile = get_old_cfile *args
        FakeFS.activate!
        cfile
      end
    end
  end

  # Compressors don't work under FakeFS
  class FakeCompressor
    def compress s
      s
    end
  end
  
  class Manifest
    alias :old_compress :compress
    def compress ext, output, compressor
      if block_given?
        old_compress ext, output, FakeCompressor.new, &Proc.new
      else
        old_compress ext, output, FakeCompressor.new
      end
    end
  end
  
  # No way to make this work with FakeFS, so just disabled it
  class Listener
    def run; end
  end

  module FakeCompiler
    Compilers.register_compiler self,
    :inputs => ["fake"],
    :outputs =>["real"],
    :dependencies => [["nonexistant_gem", ">= 9.9.9"]]
  end
end

RSpec.configure do |config|
  config.before :all do
    FakeFS.activate!
    FileUtils.mkdir("/tmp")
    @config = Slinky::ConfigReader.empty
  end
  config.before :each do
    FakeFS.activate!
    FileUtils.rm_rf("/src") rescue nil
    FileUtils.mkdir("/src")
    FileUtils.mkdir_p("/src/l1/l2/l3")
    File.open("/src/test.haml", "w+"){|f|
      f.write <<eos
!!!5
%head
  slinky_scripts
  slinky_styles
  :plain
    does this screw it up?
%body
  h1. hello
eos
    }

    File.open("/src/l1/test.sass", "w+"){|f|
      f.write <<eos
h1
  color: red
  background-image: url("bg.png")
eos
    }

    File.open("/src/l1/l2/test2.css", "w+"){|f|
      f.write <<eos
h2 { color: green; }
div { background: url('/l1/asdf.png')}
.something {background: url('l3/hello.png')}
eos
    }

    File.open("/src/l1/test.js", "w+"){|f|
      f.write <<eos
slinky_require('test2.js')
slinky_require("l2/test3.js")
eos
    }

    File.open("/src/l1/test2.js", "w+"){|f|
      f.write <<eos
slinky_require('test5.js')
eos
    }

    File.open("/src/l1/l2/test3.coffee", "w+"){|f|
      f.write <<eos
slinky_require('test6.js')
test = {do: (x) -> console.log(x)}
test.do("Hello, world")
eos
    }

    File.open("/src/l1/test5.js", "w+").close()
    File.open("/src/l1/l2/test6.js", "w+").close()

    File.open("/src/l1/l2/test.txt", "w+"){|f| f.write("hello\n") }
    File.open("/src/l1/l2/l3/test2.txt", "w+"){|f| f.write("goodbye\n") }

      @files = ["test.haml", "l1/test.js", "l1/test.sass", "l1/l2/test2.css", "l1/l2/test.txt", "l1/l2/l3/test2.txt", "l1/test2.js", "l1/l2/test3.coffee", "l1/test5.js", "l1/l2/test6.js"]

  end

  config.after :all do
    FakeFS.deactivate!
  end
end

def run_for secs
  EM.run do
    yield
    EM.add_timer(secs) {
      EM.stop_event_loop
    }
  end
end

