var Fontli;

if (typeof Fontli == 'undefined') {
  Fontli = {};
};

if (typeof Fontli.Users == 'undefined') {
  Fontli.Users = {
    extractor: function(query) {
      var result = /([^,]+)$/.exec(query);
      if(result && result[1])
        return result[1].trim();
      return '';
    },

    getCollectionNames: function() {
      var names;
      $.ajax({
        url: '/admin/collections/fetch_names',
        async: false
      }).done(function(data){
        names = data;
      });
      return names;
    },

    tagAutocomplete: function() {
      $.fn.typeahead.Constructor.prototype.select = function() {
        var val = this.$menu.find('.active').attr('data-value');
        this.$element.val(this.$element.val().replace(/[^,]*$/,' ') + val);
        this.$element.change();
        return this.hide();
      },

      $('#photo_collection_names').typeahead({
        source: Fontli.Users.getCollectionNames(),
        matcher: function (item) {
          var tquery = Fontli.Users.extractor(this.query);
          if(!tquery) return false;
          return ~item.toLowerCase().indexOf(tquery.toLowerCase());
        },
      });
    }
  }
}
$(document).ready(function() {
  // Create the chart
  if($('#users_statistics').length) {
    var facebookData = [];
    var twitterData = [];
    var emailData = []

    Highcharts.setOptions({ lang: { thousandsSep: ',' }});

    $.getJSON('/admin/user_stats?platform=twitter', function( data ) { 
      $.each( data, function( key, val ) {
        var twitter_user = {};
        twitter_user['name'] = key;
        twitter_user.y = val.total_count;
        twitter_user.drilldown = 'twitter_' + key;
        twitterData.push(twitter_user);
	      
        var twitter_drilldown_user = {};
        twitter_drilldown_user.id = 'twitter_' + key;
        twitter_drilldown_user.name = key
        twitter_drilldown_user.data = val.data;
        options.drilldown.series.push(twitter_drilldown_user);
      });
    });
      
    $.getJSON('/admin/user_stats?platform=email', function( data ) { 
      $.each( data, function( key, val ) {
        var email_user = {};
        email_user['name'] = key;
        email_user.y = val.total_count;
	email_user.color = '#dd4b39'
        email_user.drilldown = 'email_' + key;
        emailData.push(email_user);
	      
        var email_drilldown_user = {};
        email_drilldown_user.id = 'email_' + key;
        email_drilldown_user.name = key
        email_drilldown_user.data = val.data;
        options.drilldown.series.push(email_drilldown_user);
      });
    });

    $.getJSON('/admin/user_stats?platform=facebook', function( data ) { 
      $.each( data, function( key, val ) {
	var fb_user = {};
	fb_user.name = key;
	fb_user.y = val.total_count;
	fb_user.color = '#365899';
	fb_user.drilldown = 'facebook_' + key;
	facebookData.push(fb_user);
	      
	var fb_drilldown_user = {};
	fb_drilldown_user.id = 'facebook_' + key;
	fb_drilldown_user.name = key
	fb_drilldown_user.data = val.data;
	options.drilldown.series.push(fb_drilldown_user);
	chart = new Highcharts.Chart(options);
      });
    });
    var options = {
      chart: {
        renderTo: 'users_statistics',
	type: 'column'
      },
      title: {
	text: 'Users Statistics'
      },
      yAxis: {
	  title: { text: 'Count of Signup'}
      },
      xAxis: { 
	type: 'category'
      },
      legend: {
	enabled: true
      },
      plotOptions: { 
	series: 
	{ borderWidth: 0,
	  dataLabels:
	  { 
	    enabled: true,
	    style: 
	      {
                color: 'White',
                textShadow: false,
                fontSize: '12px'
	      }
	  },
	  stacking: 'normal'
	}
      },
      series: [ { name: 'Twitter', data: twitterData },
		{ name: 'Facebook', color: '#365899', data: facebookData },
		{ name: 'Email', color: '#dd4b39', data: emailData } ],
      drilldown: {
	activeDataLabelStyle: {
          color: 'white',
          textShadow: false,
          fontSize: '12px'
	},
	series: []
      }
    }
  }
});
