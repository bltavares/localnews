(function($){
  $(function() {

    var list = $("ul");

    $.get('/news/unread', function(data) {
      _.each(_.pairs(data), function(entry) {
        var key = entry.shift();
        var title = entry.shift();
        var element = $("<li />").attr("id", key).html("<span>" + title + "</span>");
        list.append(element);
      })
    });

    var unread = 0;
    $.get('/unread', function(data) {
      unread = +data;
      updateTitle(unread);
    });

    $.get('/subscriptions', function(data) {
      $("footer").append(data.join());
    });

    list.on("click", "li", function(e) {
      $this = $(this);
      if($this.hasClass("active")) {
        $this.removeClass("active");
        $this.children("div").remove();
      }
      else{
        if($this.hasClass("read")) {
          unread = unread - 1; 
          updateTitle(unread);
        } 
        $this.addClass("read");
        $.get("/news/" + $this.attr("id"), function(data) {
          var element = $("<div />");
          var title = "<h3> <a href='" + data.url + "'>" + data.title + "</a></h3>";
          element.append(title).append(data.content || data.summary);
          $this.append(element);
          $this.addClass("active");
        });
      }
    });
    function updateTitle(unread) {
      return document.title = "Localnews - " + unread;
    }
  });
})(jQuery)
