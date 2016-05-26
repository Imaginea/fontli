# See how all your routes lay out with "rake routes"
Fontli::Application.routes.draw do
  # Api controller
  match '/api/:action(.:format)', :controller => 'api_actions'

  # new web routes
  match 'feeds' => 'feeds#index', :as => :feeds
  match 'feeds/show/:id' => 'feeds#show', :as => :show_feed
  match 'socialize-feed/:id' => 'feeds#socialize_feed', :as => :socialize_feed
  match 'follow-user/:id' => 'feeds#follow_user', :as => :follow_user
  match 'unfollow-user/:id' => 'feeds#unfollow_user', :as => :unfollow_user
  match 'sos' => 'feeds#sos', :as => :sos
  match 'feed/:id/fonts' => 'feeds#fonts', :as => :feed_fonts
  match 'fonts/:family_id/:font_id' => 'feeds#show_font', :as => :show_font
  match 'recent-fonts' => 'feeds#recent_fonts', :as => :recent_fonts
  match 'profile/:user_id' => 'feeds#profile', :as => :profile
  match 'popular' => 'feeds#popular', :as => :popular
  match 'my-updates' => 'feeds#my_updates', :as => :my_updates
  match 'network-updates' => 'feeds#network_updates', :as => :network_updates
  match 'search-autocomplete' => 'feeds#search_autocomplete', :as => :search_autocomplete
  match 'search' => 'feeds#search', :as => :search
  match "font-autocomplete" => "fonts#font_autocomplete", :as => :font_autocomplete
  match "font-details/:fontname" => "fonts#font_details", :as => :font_details
  match "sub-font-details/:uniqueid" => "fonts#sub_font_details", :as => :sub_font_details
  match 'tag_font' => 'fonts#tag_font', :as => :tag_font

  # Old Unused routes
  match 'post-feed' => 'feeds#post_feed', :as => :post_feed
  match 'publish-feed/:id' => 'feeds#publish_feed', :as => :publish_feed
  match 'detail_view' => 'feeds#detail_view', :as => :detail_view
  match 'get_mentions_list' => 'feeds#get_mentions_list', :as => :get_mentions_list

  # welcome controller
  root :to => 'welcome#index'

  match 'keepalive' => 'welcome#keepalive', :as => :keepalive
  match 'signup/:platform' => 'welcome#signup', :as => :signup
  match 'login/:platform'  => 'welcome#login',  :as => :login
  match 'auth/:platform/callback' => 'welcome#auth_callback', :as => :auth_callback
  match 'logout' => 'welcome#logout', :as => :logout

  # admin controller
  match 'admin' => 'admin#index', :as => :admin
  match 'admin/:action', :controller => 'admin'

  # Resque Web
  mount Resque::Server.new, :at => "/resque"

  # Utils
  constraints :host => /(localhost|test\.fontli\.com)/i do
    match 'doc' => 'welcome#api_doc'
  end

  # Permalink - Has to be the last one
  match '*url' => 'feeds#permalink'
end
