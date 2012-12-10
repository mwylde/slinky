# Slinky 

If you write single-page rich client apps, Slinky is here to
make your life easier. For development, it provides a static file
server that transparently handles compiled languages like CoffeeScript
and SASS while supporting advanced features like dependency management,
proxying and automatic browser reloads. And once you're ready to
deploy, Slinky will compile, concatenate, and minify your sources,
leaving you ready to push to production.

[![Build Status](https://secure.travis-ci.org/mwylde/slinky.png)](http://travis-ci.org/mwylde/slinky)

What can slinky do for you?

#### Slinky Server

* Transparently compiles sources for a variety of languages
* Supports the [LiveReload](http://livereload.com) protocol, for
  instant browser updates
* Allows proxying to backend servers, so you can develop your client
  and server code separately
* Includes support for HTML5 [pushState](https://developer.mozilla.org/en-US/docs/DOM/Manipulating_the_browser_history) based apps

#### Slinky Builder

* Keeps track of the proper include order of your scripts and styles
* Compiles, minifies and concatenates JavaScript and CSS

Slinky is not a framework, and it does not want to control your source
code. Its goal is to help you when you want it&mdash;and get out of the way
when you don't. It endeavors to be sufficiently flexible to support a
wide variety of development styles.

## Quick start

```
$ gem install slinky
$ cd ~/my/awesome/project/src
$ slinky start
[hardcore web development action]
$ slinky build -o ../pub
$ scp -r ../pub/ myserver.com:/var/www/project
````

## The details

1. [LiveReload/Guard support](#livereloadguard-support)
2. [Script & style management](#script--style-management)
3. [Specifying order](#specifying-order)
4. [Dependencies](#dependencies)
5. [Configuration](#configuration)
6. [PushState](#pushstate)
7. [Proxies](#proxies)
8. [Ignores](#ignores)

### LiveReload/Guard support

The typical edit-save-reload cycle of web development can be tedious,
especially when trying to get your CSS *just* right. What if you could
reduce that to just edit-save? [LiveReload](http://livereload.com/)
allows just that. Slinky includes built-in support for LiveReload
service. All you need to do is run a browser extension (available
[here](http://go.livereload.com/extensions) for Safari, Chrome and
Firefox) or include a little script (http://go.livereload.com/mobile).
In addition to reloading your app whenever a source file changes,
LiveReload supports hot reloading of CSS, letting you tweak your
styles with ease. If don't want the LiveReload server running,
disabling it is a simple `--no-livereload` away.

### Script & style management

Slinky can manage all of your javascript and css files if you want it
to, serving them up individually during development and concatenating
and minifying them for production. To support this, Slinky recognizes
`slinky_scripts` in your HTML/HAML files. For example, when Slinky
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
appropriate HTML. You can also disable minification with the
`--dont-minify` option or the `dont_minify: true` configuration
option.

### Specifying order

Often scripts and styles depend on being included in the page
in a particular order. For this, we need the `slinky_require`
directive.

For example, consider the case of two coffeescript files, A.coffee and
B.coffee. A includes a class definition that B depends upon, so we
want to make sure that A comes before B in the concatenation order.

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
We can also do this in CSS/SASS/SC SS:

```sass
/* slinky_require("reset.css")
a
  color: red
```

### Dependencies

As HAML and SASS scripts can include external content as part of their
build process, you may want certain files to be recompiled whenever
other files change. For example, you may use mustache templates
defined each in their own file, but have set up your HAML file to
include them all into the HTML. Thus when one of the mustache files
changes, you would like the HAML file to be recompiled so that the
templates will also be updated.

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

Most of what can be specified on the command line is also available in
the configuration file. Here's a fully-decked out config:

```yaml
pushstate:
  "/app1": "/index.html"
  "/app2": "/index2.html"
proxy:
  "/test1": "http://127.0.0.1:8000"
  "/test2": "http://127.0.0.1:7000"
ignore:
  - script/vendor
  - script/jquery.js
port: 5555
src_dir: "src/"
build_dir: "build/"
no_proxy: true
no_livereload: true
livereload_port: 5556
dont_minify: true
```

Most are self explanatory, but a few of the options merit further
attention:

### PushState

[PushState](https://developer.mozilla.org/en-US/docs/DOM/Manipulating_the_browser_history)
is a new Javascript API that gives web apps more control over the
browser's history, making possible single-page javascript applications
that retain the advantages of their multi-page peers without resorting
to hacks like hash urls. The essential idea is this: when a user
navigates to a conceptually different "page" in the app, the URL
should be updated to reflect that so that behaviors such as
deep-linking and history navigation work properly. 

For this to work, however, the server must be able to return the
content of your main HTML page for arbitrary paths, as otherwise when
a user tries to reload a pushstate-enabled web app they would receive
a 404. Slinky supports multiple pushState paths using the pushstate
configuration option:

```yaml
pushstate:
  "/":     "/index.html"
  "/app1": "/app1/index.haml"
  "/app2": "/app2.haml"
```

Here, the key of the hash is a URL prefix, while the value is the file
that should actually be displayed for non-existent requests that begin
with the key. In the case of conflicting rules, the more specific one
wins. For this config, instead of returning a 404 for a path like
`/this/file/does/not/exist`, Slinky will send the content of
`/index.html`, leaving your JavaScript free to render the proper view for
that content. Similarly, a request for `/app1/photo/1/edit`, assuming
such file does not exist, will return `/app1/index.haml`.

### Proxies

Slinky has a built-in proxy server which lets you test ajax requests
with your actual backend servers without violating the same-origin
policy. To set it up, your slinky.yaml file will look something like
this:

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
request to `/search/widgets?q=foo`. When Slinky gets the request it
will see that it has a matching proxy rule, rewrites the request
appropriately (changing paths and hosts) and sends it on to the backend
server (in this case, 127.0.0.1:4567). Once it gets a response it will
wait until 2 seconds has elapsed since slinky itself received the
request and finally returns the response back to the browser.

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
