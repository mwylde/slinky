$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'slinky'
require 'fakefs/safe'
require 'fileutils'
require 'open-uri'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

module Slinky
  module CoffeeCompiler
    def CoffeeCompiler::compile s, file
      FakeFS.deactivate!
      o = CoffeeScript::compile(s)
      FakeFS.activate!
      o
    end
  end
end


RSpec.configure do |config|
  config.before :all do
    FakeFS.activate!
    FileUtils.mkdir("/tmp")
  end
  config.before :each do
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

