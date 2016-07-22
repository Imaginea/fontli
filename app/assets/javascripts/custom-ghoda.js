// document ready events
$(document).ready(function() {
 //popup
    $('.bigpic, .collapse, .likes_cnt, .fonts_cnt, .popup .set1-b').live('click', function() {
	$('.popup').toggleClass('closed open');
    });
  $('.popup .set1-c, .popup .comments_cnt').live('click', function() {
    $('.popup').toggleClass('closed open');
    $('.popup .view-typetalk').trigger('click');
    $('input[name=comment]').focus();
  });
  prevPageUrl = '';
  $('.popup .cross,.signin .img-cross').live('click', function() {
    $('#popup_container').html('').hide();
    if($('.popup').hasClass('open'))
      $('.popup').toggleClass('open closed');
    $('#popup_loader').hide(); // just in case
    $("body").css("overflow", "inherit");
    if(prevPageUrl !== '') {
      history.pushState('data', '', prevPageUrl);
    }
  });
  $(document).keyup(function(e) {
    if (e.keyCode === 27) { //ESC key
      $('#popup_container').html('').hide();
      if($('.popup').hasClass('open'))
        $('.popup').toggleClass('open closed');
      $('#popup_loader').hide(); // just in case
      if(prevPageUrl !== '') {
        history.pushState('data', '', prevPageUrl);
      }
      $("body").css("overflow", "inherit");
      $('#qr_pop').hide();
    }
  });
  // signup
  $('#join_fontli').click(function() {
    location.href = $(this).attr('href');
  });
  if(typeof($('#slider1').lemmonSlider) !== 'undefined') {
    $('#slider1').lemmonSlider({
      infinite: true
    });
  }
  $('li[rel=popitup]').live('click', function() {
    var url = $(this).attr('href');
    var id  = $(this).attr('data-id');
    photoDetailPopup(id,url);
  });
  $('div[rel=popitup] .popitup').live('click', function() {
    var elem = $(this).parents('div[rel=popitup]');
    var url = elem.attr('href');
    var id  = elem.attr('data-id');
    photoDetailPopup(id,url);
  });
  $('a.set4, a.set5').live('click', function() {
    var url = $(this).attr('data-href');
    var id = $(this).attr('data-id');
    url = url.replace('/0', '/'+id); // append id to the url
    var elem = $(this);
    elem.hide(); // avoid further clicks
    // bring the popup to closed state, if opened
    if($('.popup').hasClass('open')) {
      $('.popup').toggleClass('open closed');
      setTimeout(function() { $('#popup_loader').show(); }, 500);
    }else $('#popup_loader').show();
    spottedContentLoaded = false;

    $.ajax({
      url: url,
      success: function(data, textStatus) {
        var reponseScript = $(data).filter("script");
        $.each(reponseScript, function(idx, val) { eval(val.text); } );

        var leftPop = $(data).first().find('.left-pop').html();
        var rightPop = $(data).first().find('.right-pop').html();
        $('#popup_container .right-pop').hide();
        $('#popup_container .left-pop').fadeOut(0, function() {
          hideAjaxLoader(true);
          $('#popup_container .left-pop').html(leftPop);
          history.pushState('data', '', $('#permalink_url').attr('data'));
          $('#popup_container .right-pop').html(rightPop);
        }).fadeIn(400, function() {
          $('#popup_container .right-pop').show();
          setTypetalkHeight();
          enableScrollBars('.aa-typetalk');
          enableScrollBars('.aa-likes');
          setupPopupNavLinks(id);
        });
        elem.show();
        twttr.widgets.load();
        //FB.XFBML.parse();
      },
      error: function() {
        hideAjaxLoader(true);
        alert('Oops, An error occured!');
        $('#popup_container').hide();
      }
    });
    return false;
  });
  $('li.banner-cta, .notifications-count-box').live('click', function() {
    var url = $(this).attr('href');
    location.href = url;
  });
  // ajax request links with remote=true
  $('a[remote=true],button.follow-btn').live('click', function() {
    var url = $(this).attr('data-href');
    $('#scroll_top').addClass('hidden');
    showAjaxLoader();
    $.ajax({ url: url, dataType: 'script',
      complete: function() {
        // on pages with infite scroll, scroll to the top
        // after loading the new content via ajax
        if($('#pinned_header')) {
          $('#pinned_header').removeClass('fixed-top');
          var pos = $('#pinned_header').position().top;
          headerTop = pos;
          $('html, body').animate({scrollTop: pos+'px'}, 500);
        }
        hideAjaxLoader();
      }
    });
  });
  // ajax request forms with remote=true
  $('form[data-remote=true]').live('submit', function(e) {
    var url = $(this).attr('action');
    var params = $(this).serializeArray();
    showAjaxLoader();
    $.ajax({
      url: url,
      type: 'POST',
      dataType: 'script',
      data: params,
      complete: hideAjaxLoader
    });
    e.preventDefault();
    return false;
  });
  $('.login-req').live('click', function() {
    var url = 'http://' + location.host + '/login/default';
    showAjaxLoader();
    $.ajax({url: url, dataType: 'script'});
  });
  spottedContentLoaded = false;
  $('.popup .view-spotted, .popup .fonts_cnt, .popup .set1-b').live('click', function() {
    var url = $(this).attr('data-url');
    if(spottedContentLoaded) {
      animatePopup('aa-spotted');
    }else {
      var elem = $(this);
      elem.attr('disabled', 'disabled');
      $.ajax({
        url: url,
        success: function(data, textStatus) {
          loadSpottedContent(data, elem);
        }
      });
    }
    hideSpotContent();
    $('.right-pop .like-box.pop-nav a').removeClass('strong');
    $(this).addClass('strong');
    $('.right-pop .bottom-nav').hide();
    updateScrollBars('.aa-spotted');
  });
  $('.popup .view-typetalk').live('click', function() {
    animatePopup('aa-typetalk');
    hideSpotContent();
    $('.right-pop .like-box.pop-nav a').removeClass('strong');
    $(this).addClass('strong');
    $('.right-pop .bottom-nav').show();
    updateScrollBars('.aa-typetalk');
  });
  $('.popup .view-likes').live('click', function() {
    animatePopup('aa-likes');
    hideSpotContent();
    $('.right-pop .like-box.pop-nav a').removeClass('strong');
    $('.right-pop .like-box.pop-nav a.view-likes').addClass('strong');
    $('.right-pop .bottom-nav').hide();
    updateScrollBars('.aa-likes');
  });
  $('.right-pop .like-box.pop-nav a.spot').live('click', function() {
    $('.popup .view-spotted').trigger('click');
    $('.right-pop .content-a').hide();
    $('.right-pop .like-box.spot-search').show();
  });
  $('.right-pop input[name=spot-search]').live('keyup.autocomplete', function(){
    $(this).autocomplete({
      source: '/font-autocomplete',
      minLength: 3,
      select: function(e, ui) {
        if(!(ui.item)) return false;
        $(this).blur();
        var url = '/font-details/' + ui.item.value;
        showAjaxLoader();
        $.ajax({url: url, dataType: 'script'});
      }
    });
  });
  $('.search input[name=search]').live('keyup.autocomplete', function(){
    $(this).autocomplete({
      source: '/search-autocomplete',
      minLength: 3,
      select: function(e, ui) {
        if(!(ui.item)) return false;
        $(this).parents('form').submit();
      }
    });
  });
  $('.search-results-container a.expand-results').click(function() {
    var targetId = $(this).closest('div').attr('id') + '_more';
    $('#'+targetId).toggle();
  });
  /**
  $('.qrcode a, .qrcode-links a').click(function() {
    var klass = $(this).attr('class');
    var offset = $(window).scrollTop();
    $('#qr_pop .img-qrcode').hide(); // hide both codes
    $('#qr_pop .img-qrcode.'+klass).show(); //show relavant
    //$("body").css("overflow", "hidden");
    centerPopup('.ipad-landing-popup');
    $('#qr_pop').show();
  });
  $('#qr_pop a.close-icon').click(function() {
    $('#qr_pop').hide();
    $("body").css("overflow", "inherit");
  });
  **/
  $('.comment-form').live('submit', function(e) {
    var url = $(this).attr('action');
    var input = $('.comment-form input[name=comment]');
    var comment = input.val().trim();
    if(comment !== "") {
      showAjaxLoader();
      var params = $(this).serializeArray();
      $.ajax({url: url, data: params, dataType: 'script'});
    }
    input.val('').blur();
    return false;
  });
  $('.spot-this').live('click', function() {
    var uniqueID = $(this).parent().attr('data-id');
    enableTagLocator(uniqueID);
    $('.right-pop .set3c .spotted').css('display', 'none'); // hide all
    $(this).parent().css('display', 'block'); // show relevant
  });
  $('#scroll_top').click(function() {
    $('#pinned_header').removeClass('fixed-top');
    $('html, body').animate({scrollTop: '0px'}, 0);
  });
});

// window load events
$(window).load(function() {
  loadMoreImages('next');
  userCountdownTimer = 0;
  timeout = setTimeout(function() {
    $('.controls .next-page').trigger('click');
  }, userCountdownTimer + 7000);
  interval = null;
  setInterval(function() {
    if($('#slideshow').length !== 0) slideSwitch();
  }, userCountdownTimer + 8000);
  $('.controls a').click(function() {
    var direction = $(this).attr('class').replace('-page', '');
    loadMoreImages(direction);
    clearTimeout(timeout);
    clearInterval(interval);
  });
});

function loadMoreImages(direction) {
  var limit = 5;
  if(direction === 'prev') limit = limit * -1;
  setImageSource($('img[class=hidden-img][xsrc]').slice(limit));
  setImageSource($('img[class!=hidden-img][xsrc]').slice(limit));
}

function setImageSource(fields) {
  fields.each(function() {
    $(this).attr('src', $(this).attr('xsrc'));
    $(this).removeAttr('xsrc');
  });
}

function isMobReq() {
  var ua = navigator.userAgent.toLowerCase();
  var res = ua.match(/windows\sphone|iphone|android/) !== null;
  return res;
}
function photoDetailPopup(id, url) {
  showAjaxLoader(true);
  if(interval) clearInterval(interval);
  clearTimeout(timeout);
  spottedContentLoaded = false;
  $.ajax({
    url: url,
    success: function(data, textStatus) {
      hideAjaxLoader(true);
      var reponseScript = $(data).filter("script");
      $.each(reponseScript, function(idx, val) { eval(val.text); } );
      //$("body").css("overflow", "hidden");
      $('#popup_container').html(data);

      prevPageUrl = location.href;
      history.pushState('data', '', $('#permalink_url').attr('data'));

      centerPopup('.popup');
      setTypetalkHeight();
      enableScrollBars('.aa-typetalk');
      enableScrollBars('.aa-likes');
      setupPopupNavLinks(id);
      twttr.widgets.load();
      //FB.XFBML.parse();
    },
    error: function() {
      hideAjaxLoader(true);
      alert('Oops, An error occured!');
      $('#popup_container').hide();
    }
  });
}
function showAjaxLoader(popup) {
  if(popup) {
    centerPopup('.popup');
    $('#popup_container').html($('#popup_loader').html());
    $('#popup_container').show(); }
  else {
    $('#ajax_loader').show();
  }
}
function hideAjaxLoader(popup) {
  if(popup) $('#popup_loader').hide();
  else $('#ajax_loader').hide();
}
function centerPopup(selector) {
  var elem = $(selector);
  var marginTop;

  if(isMobReq()) {
    marginTop = 0; }
  else {
    var windowHeight = $(window).height();
    var popupHeight = elem.height();
    marginTop = (windowHeight - popupHeight) / 2;
  }
  elem.css('margin-top', marginTop + 'px');
}
function getDocHeight() {
  return ($(document).height() || $(document).innerHeight());
}
function animatePopup(ele) {
  rightPopup = $('.popup .right-pop');
  $.each(['aa-spotted', 'aa-likes', 'aa-typetalk'], function(i, field_id) {
    if (field_id === ele)
      rightPopup.find('.'+field_id).fadeIn(1000);
    else
      rightPopup.find('.'+field_id).hide();
  });
}
function setupPopupNavLinks(id) {
  //expects photoIds variable set on the main page
  //if not just hide the left/right arrows
  if(photoIds.length === 0) {
    $('.popup .set5').hide();
    $('.popup .set4').hide();
    return false;
  }
  var i = photoIds.indexOf(id);
  var last = photoIds.length - 1;
  var nextID = photoIds[i+1];
  var prevID = photoIds[i-1];
  //cycle through the list if its last or first
  if(i === last) nextID = photoIds[0];
  else if(i === 0) prevID = photoIds[last];
  $('.popup .set5').attr('data-id', nextID);
  $('.popup .set4').attr('data-id', prevID);
}
function enableScrollBars(selector) {
  if(typeof($(selector).mCustomScrollbar) === 'undefined') return true;
  $(selector).mCustomScrollbar({
	  scrollButtons:{
			enable:true
		}
 	});
}
function updateScrollBars(selector) {
  if(typeof($(selector).mCustomScrollbar) === 'undefined') return true;
  $(selector).mCustomScrollbar('update');
}
function slideSwitch() {
  var $active = $('#slideshow DIV.active');
  if ( $active.length === 0 ) $active = $('#slideshow DIV:last');
  // use this to pull the divs in the order they appear in the markup
  var $next =  $active.next().length ? $active.next() : $('#slideshow DIV:first');
  // uncomment below to pull the divs randomly
  // var $sibs  = $active.siblings();
  // var rndNum = Math.floor(Math.random() * $sibs.length );
  // var $next  = $( $sibs[ rndNum ] );
  $active.addClass('last-active');
  $next.css({opacity: 0.0})
    .addClass('active')
    .animate({opacity: 1.0}, 1000, function() {
      $active.removeClass('active last-active');
    });
}
// use this to position the view spotted/view typetalk link at the bottom of the popup.
function setTypetalkHeight() {
  var totalHeight = 428; // 615px - 55px(header) - 29px(padding) - 38px(like-box) - 65px(margin-bottom)
  var captionHeight = $('.right-pop .content-a').height();
  $('.right-pop .content-b').css('height', (totalHeight - captionHeight) + 'px');
}
function updateCounter(val,digit,elem) {
  var klass = elem.attr('class');
  var slot = $('<strong></strong>');
  slot.html(val);
  slot.css({opacity:0,position:'relative',left:'0px','top':'-10px'});
  slot.attr('class', klass + 'a');

  userCountdownTimer += 150;
  setTimeout(function() {
    elem.after(slot);
    $('.'+klass).fadeOut(0);
    slot.animate({opacity:1, top:0}, 50);
    slot.attr('class', klass);
  }, userCountdownTimer);
}
function hideSpotContent() {
  $('#tag_locator').hide();
  $('.right-pop .like-box.spot-search').hide();
  $('.right-pop .recent-likes').html('').hide();
  $('.right-pop .like-box.spot-preview').hide();
  $('.right-pop .aa-spot-list').hide();
  $('.right-pop .aa-spot-list-family').hide();
  $('.right-pop .content-a').show();
  setTypetalkHeight();
}
function enableTagLocator(fontUniqueID) {
  var tagForm = $("#tag_form_" + fontUniqueID);
  var coordsInput = tagForm.find('.coords-input');
  var photoIDInput = tagForm.find('.photo-id-input');
  photoIDInput.val($('.bigpic').attr('data-id'));

  $('#tag_labelmark').draggable({
    containment: ".bigpic",
    scroll: false,
    cursor: "move",
    cursorAt: { top: 25, left: 25 },
    start: function() {
      $(this).parent().find('p').hide();
    },
    drag: function() { },
    stop: function() {
      var left = $(this).position().left;
      var top = $(this).position().top;
      coordsInput.val(left + ',' + top);
      tagForm.trigger('submit');
    }
  });

  // reset any drag already happened
  $('#tag_labelmark').css({left:'0px', top:'0px'});
  $('#tag_locator p').show();
  // we are ready to show
  $('#tag_locator').show();
}
function loadSpottedContent(data, elem) {
  $('.popup .right-pop .aa-spotted').html(data);
  spottedContentLoaded = true;
  if(elem) elem.removeAttr('disabled');
  animatePopup('aa-spotted');
  enableScrollBars('.aa-spotted');
}
