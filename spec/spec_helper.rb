$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'rspec'
require 'slinky'
require 'fakefs/safe'
require 'tmpdir'
require 'fileutils'
require 'open-uri'

module Slinky
  class Runner
    def version
      "0.8.0"
    end
  end

  # The coffee script compiler doesn't work under FakeFS
  module CoffeeCompiler
    def CoffeeCompiler::compile s, file
      FakeFS.without {
        CoffeeScript::compile(s)
      }
    end
  end

  # The JSX compiler doesn't work under FakeFS
  module JSXCompiler
    class << self
      alias :old_compile :compile
      def JSXCompiler::compile s, file
        FakeFS.without {
          old_compile(s, file)
        }
      end
    end
  end

  module SassCompiler
    class << self
      alias :old_compile :compile
      def SassCompiler::compile s, file
        FakeFS.without {
          old_compile(s, file)
        }
      end
    end
  end

  # This is necessary because require doesn't work with FakeFS
  class Compilers
    class << self
      alias :get_old_cfile :get_cfile
      def get_cfile *args
        FakeFS.without {
          get_old_cfile *args
        }
      end
    end
  end

  class Manifest
    def compressor_for_product product
      # Compressors don't work under FakeFS
      lambda{|s| s}
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
    FileUtils.rm_rf("/tmp") rescue nil
    FileUtils.mkdir("/tmp")
    @config = Slinky::ConfigReader.empty
  end

  config.before :each do
    FakeFS.activate!
    FileUtils.rm_rf("/src") rescue nil
    FileUtils.rm_rf("/build") rescue nil
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
console.log("Hello!");
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

    @files = ["test.haml", "l1/test.js", "l1/test.sass",
              "l1/l2/test2.css", "l1/l2/test.txt", "l1/l2/l3/test2.txt",
              "l1/test2.js", "l1/l2/test3.coffee", "l1/test5.js",
              "l1/l2/test6.js"]
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

# Create an empty file and the enclosing directory, if needed
def cf(file)
  FileUtils.mkdir_p(Pathname.new(file).dirname)
  File.open(file, "w+").close
end
