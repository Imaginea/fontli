var Fontli;

if (typeof Fontli == 'undefined') {
  Fontli = {};
};

if (typeof Fontli.Custom == 'undefined') {
  Fontli.Custom = {
    init: function() {
      $('#cover_photo').live('change', function() {
        $(this).parent().find('img').remove();
      })
    }
  }
}

$(document).ready(function() {
  Fontli.Custom.init();
})
