#Slinky

Slinky helps you write rich web applications using compiled web
languages like SASS, HAML and CoffeeScript. The slinky server
transparently compiles resources as they're requested, leaving you to
worry about your code, not how to compile it.

Once your ready for production, the slinky builder will compile all of
your sources and concatenate and minify your javascript and css,
leaving you a directory that's ready to be pushed to your servers.

## Quickstart

```
$ gem install slinky
$ cd ~/my/awesome/project
$ slinky start
[hardcore web development action]
$ slinky build
$ scp -r build/ myserver.com/var/www/project
````
## But tell me more!

Slinky currently supports three languages for compilation, SASS/SCSS,
HAML and CoffeeScript, but it's simple to add support for others (and
please submit a pull request when you do!). Slinky also has a few
tricks of its own for managing the complexity of modern web
development.

### Script & style management

Slinky can manage all of your javascript and css files if you want it
to, serving them up individually during development and concatenating
and minifying them for production. To support this, Slinky recognizes
`slinky_scripts` in your HTML/Haml files. For example, when Slinky
sees this:

```haml
!!!5
%html
  %head
    slinky_scripts
    slinky_styles
  %body
    %h1 Hello, world!
```

it will compile the HAML to HTML and replace slinky_styles with the
appropriate HTML.

### Specifying order

But what if your scripts or styles depend on being included in the
page in a particular order? For this, we need the `slinky_require`
directive.

For example, consider the case of two coffeescript files, A.coffee and
B.coffee. A includes a class definition that B depends upon, so we
want to make sure that A comes before B in the concatenation order. We
can solve this simply using `slinky_require(script)`

File A.coffee:
```coffeescript
class A
  hello: (thing) -> "Hello, " + thing
```

File B.coffee:
```coffeescript
slinky_require("a.coffee")
alert (new A).hello("world")
```
We can also do this in CSS/SASS/SCSS:

```sass
/* slinky_require("reset.css")
a
  color: red
```

### And coming up next...

* Support for more languages
* Built in proxy-server to allow connections to web services
* More control over behavior
