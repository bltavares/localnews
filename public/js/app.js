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

    $("#refresh").on('click', function(e) { 
      $(this).text("Updating...");
    });

    var unread = 0;
    $.get('/unread', function(data) {
      unread = +data;
      updateTitle(unread);
    });

    $.get('/subscriptions', function(data) {
      $("footer").append(data.join(", "));
    });

    list.on("click", "li", function(e) {
      $this = $(this);
      if(!$this.hasClass("active")) {
        if($this.hasClass("read")) {
          unread = unread - 1; 
          updateTitle(unread);
        } 
        $this.addClass("read");
        index = list.children().index($this);
        $(document).scrollTo(this, {axis: 'y', margin: true});
        $.get("/news/" + $this.attr("id"), function(data) {
          var element = $("<div />");
          var title = "<h3> <a href='" + data.url + "' target='_blank'>" + data.title + "</a></h3>";
          element.append(title).append(data.content || data.summary);
          $this.append(element);
          $this.addClass("open");
        });
      }
      list.children().removeClass('active').children("div").remove();
      $this.addClass('active');
    });
    var index = -1;
    KeyboardJS.on('j', function() {
      list.children().eq(index + 1).click();
    });
    KeyboardJS.on('k', function() {
      list.children().eq(index - 1).click();
    });
    KeyboardJS.on('v', function() {
      window.open(list.children().eq(index).find("div > h3 > a:first").attr("href"));
    });
    KeyboardJS.on('m', function() {
      var entry = list.children().eq(index);
      entry.removeClass("read");
      unread = unread + 1;
      updateTitle(unread);
      $.ajax('/news/' + entry.attr("id"), {
        type: "put",
        data: { "state": "unread" } 
      });
    });
  });
  function updateTitle(unread) {
    return document.title = "Localnews - " + unread;
  }
})(jQuery)
