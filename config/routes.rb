# See how all your routes lay out with "rake routes"
Fontli::Application.routes.draw do
  # Api controller
  API_ACTIONS = [:log_crash, :stats, :features, :signin, :signup, :signout, :forgot_pass, :reset_pass,
                 :login_check, :check_token, :collections, :collection_search, :follow_collection,
                 :unfollow_collection, :collection_detail, :add_photo_to_collections, :upload_data,
                 :publish_photo, :photo_detail, :update_photo, :delete_photo, :like_photo, :unlike_photo,
                 :flag_photo, :flag_user, :share_photo, :comment_photo, :comments_list, :delete_comment,
                 :add_to_sos, :agree_font, :unagree_font, :fav_font, :unfav_font, :likes_list, :mentions_list,
                 :hash_tag_search, :hash_tag_photos, :hash_tag_feeds, :leaderboard, :popular_photos,
                 :sos_photos, :popular_fonts, :recent_fonts, :font_photos, :font_heat_map, :user_search,
                 :user_profile, :update_profile, :invite_friends, :my_invites, :my_invites_opt, :user_friends,
                 :user_followers, :user_photos, :user_popular_photos, :user_favorites, :user_fonts,
                 :user_fav_fonts, :follow_user, :unfollow_friend, :add_suggestion, :feeds_html,
                 :my_notifications_count, :my_updates, :network_updates, :my_feeds, :feed_detail,
                 :add_workbook, :update_workbook, :list_workbooks, :workbook_photos, :fav_workbook,
                 :unfav_workbook, :recommended_users, :homepage_photos].freeze

  API_ACTIONS.each do |action|
    match "/api/#{action}", to: "api_actions##{action}"
  end

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
  match 'font-autocomplete' => 'fonts#font_autocomplete', :as => :font_autocomplete
  match 'font-details/:fontname' => 'fonts#font_details', :as => :font_details
  match 'sub-font-details/:uniqueid' => 'fonts#sub_font_details', :as => :sub_font_details
  match 'tag_font' => 'fonts#tag_font', :as => :tag_font

  # Old Unused routes
  match 'post-feed' => 'feeds#post_feed', :as => :post_feed
  match 'publish-feed/:id' => 'feeds#publish_feed', :as => :publish_feed
  match 'detail_view' => 'feeds#detail_view', :as => :detail_view
  match 'get_mentions_list' => 'feeds#get_mentions_list', :as => :get_mentions_list

  # welcome controller
  root to: 'welcome#index'

  match 'keepalive' => 'welcome#keepalive', :as => :keepalive
  match 'login/:platform'  => 'welcome#login',  :as => :login
  #match 'auth/:platform/callback' => 'welcome#auth_callback', :as => :auth_callback

  # admin controller
  get 'admin', to: 'admin#index', as: 'admin'

  resource :admin, controller: :admin, only: [] do
    collection do
      get  :users, :suspended_users, :photos, :collections, :flagged_users, :flagged_photos, :sos
      get  :popular_users, :popular_fonts, :users_statistics, :user_stats, :top_contributors
      get  :popular_photos, :send_push_notifications
      post :create_collection, :send_push_notifications, :expire_popular_cache
      put  :suspend_user, :activate_user, :activate_collection, :unflag_user, :unflag_photo
      put  :approve_sos, :select_photo, :select_for_header, :update_stat
      delete :delete_user, :delete_photo
    end
  end

  # Resque Web
  mount Resque::Server.new, at: '/resque'

  # Utils
  constraints host: /(localhost|test\.fontli\.com)/i do
    match 'doc' => 'welcome#api_doc'
  end

  # Permalink - Has to be the last one
  match '*url' => 'feeds#permalink'
end
