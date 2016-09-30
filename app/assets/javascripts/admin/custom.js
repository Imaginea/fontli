$(document).ready(function() {
  $('#cover_photo').live('change', function() {
    $(this).parent().find('img').remove();
  })
})
