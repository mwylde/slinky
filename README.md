#Slinky 

Slinky helps you write rich web applications using compiled web
languages like SASS, HAML and CoffeeScript. The slinky server
transparently compiles resources as they're requested, leaving you to
worry about your code, not how to compile it. It will even proxy
AJAX requests to a backend server so you can easily develop against
REST APIs.

Once you're ready for production the slinky builder will compile all of
your sources and concatenate and minify your javascript and css,
leaving you a directory that's ready to be pushed to your servers.

[![Build Status](https://secure.travis-ci.org/mwylde/slinky.png)](http://travis-ci.org/mwylde/slinky)

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
slinky_require("A.coffee")
alert (new A).hello("world")
```
We can also do this in CSS/SASS/SCSS:

```sass
/* slinky_require("reset.css")
a
  color: red
```

### Specifing dependencies

As HAML and SASS scripts can include external content as part of their
build process, it may be that you would like to specify that files are
to be recompiled whenever other files change. For example, you may use
mustache templates defined each in their own file, but have set up
your HAML file to include them all into the HTML. Thus when one of the
mustache files changes, you would like the HAML file to be recompiled
so that the templates can be updated also.

These relationships are specified as "dependencies," and like requirements
they are incdicated through a special `slinky_depends("file")` directive in 
your source files. For our template example, the index.haml files might look 
like this:

```haml
slinky_depends("scripts/templates/*.mustache")
!!!5

%html
  %head
    %title My App
    slinky_styles
    slinky_scripts
    - Dir.glob("./scripts/templates/*.mustache") do |f|
      - name = File.basename(f).split(".")[0..-2].join(".")
      %script{:id => name, :type => "text/x-handlebars-template"}= File.read(f)
  %body
```

## Configuration

Slinky can optionally be configured using a yaml file. By default, it
looks for a file called `slinky.yaml` in the source directory, but you
can also supply a file name on the command line using `-c`.

There are currently two directives supported:

### Proxies

Slinky has a built-in proxy server which lets you test ajax requests
with your actual backend servers. To set it up, your slinky.yaml file
will look something like this:

```yaml
proxy:
  "/login": "http://127.0.0.1:4567/login"
  "/search":
    to: "http://127.0.0.1:4567/search"
    lag: 2000
```

What does this mean? We introduce the list of proxy rules using the
`proxy` key. Each rule is a key value pair. The key is a url prefix to
match against. The first rule is equivalent to the regular expression
`/\/login.*/`, and will match paths like `/login/user` and
`/login/path/to/file.html`. The value is either a url to pass the
request on to or a hash containing configuration (one of which must be
a `to` field). Currently a `lag` field is also supported. This delays
the request by the specified number of milliseconds in order to
simulate the latency associated with remote servers.

An example: we have some javascript code which makes an AJAX GET
request to `/search/widgets?q=foo`. When slinky gets the request it
will see that it has a matching proxy rule, rewrite the request
appropriately (changing paths and hosts) and send it on to the backend
server (in this case, 127.0.0.1:4567). Once it gets a response it will
wait until 2 seconds has elapsed since slinky itself received the
request and then send on the response back to the browser.

This is very convenient for developing rich web clients locally. For
example, you may have some code that shows a loading indicator while
an AJAX request is outstanding. However, when run locally the request
returns so quickly that you can't even see the loading indicator. By
adding in a lag this problem is remedied.

###  Ignores

By default slinky will include every javascript and css file it finds
into the combined scripts.js and styles.css files. However, it may be
that for some reason you want to keep some files separate and handle
them manually. The ignore directive lets you do that, by telling the
system to skip over any files or directories listed. For example:

```yaml
ignore:
  - script/vendor
  - css/reset.css
```

This will causes everything in the script/vendor directory to be
ignored by slinky, as well as the reset.css file.
