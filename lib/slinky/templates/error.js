(function(errors) {
  var domLoaded = function() {
    var css = {REPLACE_CSS};
    var cssEl = document.createElement("style");
    cssEl.type = "text/css";
    cssEl.innerText = css.css;
    document.head.appendChild(cssEl);

    var el = document.getElementById("slinky-error");
    if(el == null) {
      el = document.createElement("div");
      el.id = "slinky-error";
      el.innerHTML = '<div class="slinky-header"><h1>Oh no! Build'
        + ' error!</h1></div><div class="slinky-body"><ul></ul></div>';
      document.body.appendChild(el);
    }

    var ul = el.getElementsByTagName("ul")[0];
    errors.forEach(function(error) {
      var li = document.createElement("li");
      li.innerText = error;
      ul.appendChild(li);
    });
  };
  document.addEventListener("DOMContentLoaded", domLoaded, false);
})({REPLACE_ERRORS});
