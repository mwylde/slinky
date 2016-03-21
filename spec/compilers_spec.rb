require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'em-http'

def compiler_test file, ext, src, dir = nil, &test
  FakeFS.without {
    dir ||= Dir.mktmpdir

    begin
      path = "#{dir}/#{file}"
      
      File.open(path, "w+"){|f| f.write(src)}
      cf = Slinky::Compilers.cfile_for_file(path)
      called_back = false

      $stdout.should_receive(:puts).with("Compiled #{path}".foreground(:green))  

      cf.compile{|cpath, _, _, error|
        error.should == nil
        cpath.nil?.should == false
        cpath.end_with?(ext).should == true
        test.call(File.open(cpath).read).should == true
        called_back = true
      }
      called_back.should == true
    ensure
      FileUtils.rm_rf(dir)
    end
  }
end

describe "Compilers" do
  context "SassCompiler" do
    it "should be able to compile SASS files" do
      src = <<eos
h1
  color: red
eos
      compiler_test("test.sass", ".css", src){|s|
        s.include?("color: red;")
      }
    end

    it "should be able to compile SCSS files" do
      src = <<eos
h1 {
  a {
    color: red;
  }
}
eos
      compiler_test("test.scss", ".css", src){|s|
        s.include?("color: red;") && s.include?("h1 a")
      }
    end

    it "should not compile partials" do
      src = "body { color: $something; }"
      compiler_test("_partial.scss", ".css", src){|s|
        s == ""
      }
    end
  end

  context "LessCompiler" do
    it "should be able to compile LESS files" do
      src = <<eos
@width: 0.5;

.class {
  width: percentage(@width);
}
eos
      compiler_test("test.less", ".css", src){|s|
        s.include?("width: 50%;")
      }
    end
  end

  context "CoffeeCompiler" do
    it "should be able to compile .coffee files" do
      src = <<eos
test = {do: (x) -> console.log(x)}
test.do("Hello, world")
eos
      compiler_test("test.coffee", ".js", src){|s|
        s.include?("function(x) {")
      }
    end
  end

  context "HamlCompiler" do
    it "should be able to compile .haml files" do
      src = <<eos
!!!5
%head
  %title Hello!
%body
eos
      compiler_test("test.haml", ".html", src){|s|
        s.include?("<title>Hello!</title>")
      }
    end
  end

  context "JSXCompiler" do
    it "should be able to compile .jsx files" do
      src = <<-EOF
  /** @jsx React.DOM */
  React.renderComponent(
    <h1>Hello, world!</h1>,
    document.getElementById('example')
  );
EOF
      compiler_test("test.jsx", ".js", src){|s|
        s.include?("Hello, world!")
      }
    end
  end

  context "TypescriptCompiler" do
    it "should be able to compile .ts files" do
      src = <<-EOF
function greeter(person: string) {
    return "Hello, " + person;
}

var user = "Jane User";
EOF
      compiler_test("test.ts", ".js", src){|s|
        s.include?("function greeter(person)")
      }
    end

    it "should be able to reference definition files" do
      dts = <<-EOF
declare var Test: {x: number}
EOF
      
      src = <<-EOF
///<reference path="types/my.d.ts">

console.log(Test.x + 5);
EOF

      FakeFS.without {      
        dir = Dir.mktmpdir

        FileUtils.mkdir("#{dir}/types")
        File.open("#{dir}/types/my.d.ts", "w+"){|f| f.write(dts)}

        compiler_test("test.ts", ".js", src, dir){|s|
          s.include?("Test.x")
        }
      }
    end
  end
end
