require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'em-http'

def compiler_test file, ext, src, &test
  File.open(file, "w+"){|f| f.write(src)}
  cf = Slinky::Compilers.cfile_for_file(file)
  called_back = false

  $stdout.should_receive(:puts).with("Compiled #{file}".foreground(:green))  

  cf.compile{|cpath, _, _, error|
    error.should == nil
    cpath.nil?.should == false
    cpath.end_with?(ext).should == true
    test.call(File.open(cpath).read).should == true
    called_back = true
  }

  called_back.should == true
end

describe "Compilers" do
  before :each do
    FileUtils.rm_rf("/compilers") rescue nil
    FileUtils.mkdir("/compilers")
  end

  context "SassCompiler" do
    it "should be able to compile SASS files" do
      src = <<eos
h1
  color: red
eos
      compiler_test("/compilers/test.sass", ".css", src){|s|
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
      compiler_test("/compilers/test.scss", ".css", src){|s|
        s.include?("color: red;") && s.include?("h1 a")
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
      compiler_test("/compilers/test.less", ".css", src){|s|
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
      compiler_test("/compilers/test.coffee", ".js", src){|s|
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
      compiler_test("/compilers/test.haml", ".html", src){|s|
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
      compiler_test("/compilers/test.jsx", ".js", src){|s|
        s.include?("Hello, world!")
      }
    end
  end
end
