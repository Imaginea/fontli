# maintain the signature outside of controller. Mimic of ActionWebService pattern.
# This also controls the params and helps pre-loading only the required params.
# NOTE:: Optional params(Array) has to be specified as the last option within :accepts.
module ApiHelper

  COMMON_RESPONSE_ATTRS  = [:notifications_count]
  SIGNATURE_MAP =
  {
    :log_crash   => { :accepts => [:content],
                      :returns => true },
    :stats       => { :accepts => [],
                      :returns => [:app_version] },
    :signin      => { :accepts => [:username, :password, :device_id],
                      :returns => 'Auth Token' },
    :signup      => { :accepts => [:username, :email, :password, [:full_name, :description, :website, :platform, :extuid, :avatar]],
                      :returns => [:id, :username, :email, :password, :url_thumb] },
    :signout     => { :accepts => [],
                      :returns => true },
    :forgot_pass => { :accepts => [:email_or_uname],
                      :returns => true },
    :reset_pass  => { :accepts => [:password, :new_password, :confirm_password],
                      :returns => true },
    :login_check => { :accepts => [],
                      :returns => true },
    :check_token => { :accepts => [],
                      :returns => true },

    :upload_data    => { :accepts => [:data, [:crop_x, :crop_y, :crop_w, :crop_h]],
                         :returns => [:id] },
    :publish_photo  => { :accepts => [:photo_id, :caption, [:latitude, :longitude, :address, :font_help, :font_tags, :hashes]],
                         :returns => [:id, :user_id, :caption, :created_dt, :url, :permalink],
                         :collection => {:font_tags => [:family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :img_url, :coords],
                                         :hashes => [:name] }},

    :photo_detail   => { :accepts => [:photo_id],
                         :returns => [:id, :user_id, :caption, :created_dt, :url_large, :user_url_thumb, :username, :permalink, :likes_count, :fonts_count, :comments_count, :fonts_ord, :address, :latitude, :longitude, :liked?, :commented?, :liked_user, :commented_user, :font_help, :hash_tags],
                         :fonts_ord => [:id, :user_id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :img_url, :tags_count, :agrees_count, :my_agree_status, :pick_status, :my_fav?, :expert_tagged],
                         :hash_tags => [:name] },
    :delete_photo   => { :accepts => [:photo_id],
                         :returns => true },
    :like_photo     => { :accepts => [:photo_id],
                         :returns => [:likes_count] },
    :unlike_photo   => { :accepts => [:photo_id],
                         :returns => [:likes_count] },
    :flag_photo     => { :accepts => [:photo_id],
                         :returns => [:flags_count] },
    :flag_user      => { :accepts => [:user_id],
                         :returns => [:user_flags_count] },
    :share_photo    => { :accepts => [:photo_id],
                         :returns => true },
    :comment_photo  => { :accepts => [:photo_id, :body, [:font_tags, :hashes, :foto_ids]],
                         :returns => [:id, :body, :user_url_thumb, :username, :user_id, :created_dt, :fonts],
                         :collection => {:font_tags => [:family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :img_url, :coords],
                                         :hashes => [:name]},
                         :fonts    => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :my_agree_status, :pick_status, :img_url, :my_fav?, :coords, :expert_tagged] },

    :comments_list  => { :accepts => [:photo_id],
                         :returns => [:id, :body, :user_url_thumb, :username, :user_id, :created_dt, :fonts, :fotos],
                         :fonts   => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :my_agree_status, :pick_status, :img_url, :my_fav?, :coords, :expert_tagged],
                         :fotos   => [:id, :url_thumbs] },
    :delete_comment => { :accepts => [:comment_id],
                         :returns => true },
    :agree_font     => { :accepts => [:font_id, [:close_help]],
                         :returns => true },
    :unagree_font   => { :accepts => [:font_id],
                         :returns => true },
    :fav_font       => { :accepts => [:font_id, :thumb_url],
                         :returns => true },
    :unfav_font     => { :accepts => [:font_id],
                         :returns => true },
    :likes_list     => { :accepts => [:photo_id, [:page]],
                         :returns => [:id, :username, :full_name, :url_thumb, :friendship_state] },

    :mentions_list  => { :accepts => [[:photo_id]],
                         :returns => [:username, :user_id, :full_name] },
    :hash_tag_search => { :accepts => [:name],
                          :returns => [:name, :photos_count] },
    :hash_tag_photos => { :accepts => [:name, [:page]],
                          :returns => [:id, :url_thumb] },
    :leaderboard    => { :accepts => [],
                         :returns => [:id, :username, :full_name, :points, :url_thumb, :photos_count, :fonts_count, :created_dt, :friendship_state ] },

    :feeds_html     => { :accepts => [],
                         :returns => 'Feeds HTML' },
    :my_updates     => { :accepts => [[:page]],
                         :returns => 'Updates HTML' },
    :network_updates => { :accepts => [],
                          :returns => 'Network Updates HTML' },
    :my_feeds       => { :accepts => [[:page]],
                         :returns => [:id, :user_id, :caption, :created_dt, :url_large, :username, :user_url_thumb, :permalink, :likes_count, :fonts_count, :comments_count, :fonts_ord, :address, :latitude, :longitude, :font_help, :liked?, :commented?, :liked_user, :commented_user],
                         :fonts_ord => [:user_id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :pick_status, :img_url, :my_fav?, :expert_tagged] },
    :feed_detail    => { :accepts => [:feed_id],
                         :returns => [:id, :user_id, :caption, :created_dt, :url_large, :username, :user_url_thumb, :permalink, :likes_count, :fonts_count, :comments_count, :fonts_ord, :address, :latitude, :longitude, :font_help, :liked?, :commented?, :liked_user, :commented_user],
                         :fonts_ord => [:user_id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :pick_status, :my_fav?, :expert_tagged] },

    :popular_photos => { :accepts => [],
                         :returns => [:id, :user_id, :caption, :created_dt, :url_large, :url_thumb] },
    :sos_photos     => { :accepts => [[:page]],
                         :returns => [:id, :user_id, :caption, :created_dt, :url_large, :url_thumb] },
    :popular_fonts  => { :accepts => [],
                         :returns => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :img_url, :pick_status, :my_fav?, :expert_tagged] },
    :recent_fonts   => { :accepts => [],
                         :returns => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :tags_count, :agrees_count, :img_url, :thumb_url, :pick_status, :my_fav?, :expert_tagged] },
    :font_photos    => { :accepts => [:family_id, [:page]],
                         :returns => [:id, :url_thumb] },
    :font_heat_map  => { :accepts => [:font_id],
                         :returns => [:id, :family_unique_id, :family_id, :family_name, :subfont_name, :subfont_id, :tags_count, :heat_map, :tagged_users],
                         :heat_map => [:cx, :cy, :count],
                         :tagged_users => [:id, :url_thumb, :username, :full_name, :friendship_state] },

    :user_search    => { :accepts => [:name],
                         :returns => [:id, :username, :full_name, :url_thumb, :photos_count, :fonts_count, :points, :friendship_state] },
    :user_profile   => { :accepts => [[:user_id, :username]],
                         :returns => [:id, :username, :email, :full_name, :description, :website, :url, :url_large, :url_thumb, :created_dt, :likes_count, :follows_count, :followers_count, :photos_count, :fonts_count, :my_photos, :my_friend?],
                         :my_photos => [:id, :url_thumb]},
    :update_profile => { :accepts => [[:email, :full_name, :description, :website, :iphone_token, :wp_toast_url, :avatar]],
                         :returns => true },
    :user_friends   => { :accepts => [[:user_id, :page]],
                         :returns => [:url_thumb, :username, :full_name, :email, :id, :friendship_state] },
    :user_followers => { :accepts => [[:user_id, :page]],
                         :returns => [:url_thumb, :username, :full_name, :email, :id, :friendship_state] },
    :user_favorites => { :accepts => [[:user_id, :page]],
                         :returns => [:id, :url_thumb] },
    :user_photos    => { :accepts => [[:user_id, :page]],
                         :returns => [:id, :url_thumb] },
    :user_fonts     => { :accepts => [[:user_id, :page]],
                         :returns => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :my_fav?] },
    :user_fav_fonts => { :accepts => [[:user_id, :page]],
                         :returns => [:id, :family_unique_id, :family_name, :family_id, :subfont_name, :subfont_id, :img_url, :my_fav?, :expert_tagged] },
    :my_notifications_count => { :accepts => [],
                                 :returns => [:notifications_count] },

    :invite_friends   => { :accepts => [:friends],
                           :returns => true,
                           :collection => {:friends => [:full_name, [:email, :extuid, :platform]] } },
    :my_invites       => { :accepts => [],
                           :returns => [:email, :extuid, :platform, :invite_state, :id] },
    :my_invites_fb    => { :accepts => [:friends],
                           :returns => true,
                           :collection => {:friends => [:full_name, :extuid] } },
    :unfollow_friend  => { :accepts => [:friend_id],
                           :returns => true },
    :follow_user      => { :accepts => [:user_id],
                           :returns => true },
    :add_suggestion   => { :accepts => [:text, :platform, :os_version, :sugg_type, :app_version],
                           :returns => true },
    :add_workbook     => { :accepts => [:title, [:description, :hashes, :foto_ids, :cover_photo_id, :ordered_foto_ids]],
                           :returns => [:id, :title] },
    :update_workbook  => { :accepts => [:workbook_id, [:title, :description, :hashes, :foto_ids, :removed_foto_ids, :cover_photo_id, :ordered_foto_ids]],
                           :returns => [:id, :title] },
    :list_workbooks   => { :accepts => [[:user_id]],
                           :returns => [:id, :title, :description] },
    :workbook_photos  => { :accepts => [:workbook_id],
                           :returns => [:id, :url_thumb, :cover, :position] },
    :fav_workbook     => { :accepts => [:workbook_id],
                           :returns => true },
    :unfav_workbook   => { :accepts => [:workbook_id],
                           :returns => true },
    :recommended_users => { :accepts    => [] ,
                            :returns    => [:id, :username, :url_thumb, :created_dt, :recent_photos, :description, :full_name, :friendship_state],
                            :recent_photos => [:id, :url_thumb] }

 }

  GUEST_USER_ALLOWED_APIS = [:signin, :signup, :check_token, :popular_photos, :photo_detail, :comments_list, :likes_list]
  AUTHLESS_APIS           = [:signin, :signup, :forgot_pass, :check_token, :login_check, :stats, :log_crash]

  ERROR_MESSAGE_MAP =
  {
    :user_not_found     => 'User Not Found!',
    :session_not_found  => 'Session Not Found!',
    :record_not_found   => 'Record Not Found!',
    :pass_blank         => 'Password cannot be blank.',
    :cur_pass_blank     => 'Current Password cannot be blank.',
    :pass_not_match     => 'Invalid Password. Please try again.',
    :cur_pass_not_match => 'Current Password is invalid! Please try again.',
    :unable_to_login    => 'Invalid Username or Password!',
    :duplicate_signup   => 'User ID Already Taken',
    :param_missing      => 'Parameters mismatch! Please check the api doc.',
    :unable_to_save     => 'Action Not Complete, Try Again Later',
    :token_not_found    => 'Token not found! Please signin again',
    :token_expired      => 'Session expired. Please signin again!',
    :guest_not_allowed  => 'Access restricted for guest users. Please signup.',
    :photo_not_found    => 'Photo not found!',
    :font_not_found     => 'Font not found!',
    :duplicate_favs     => 'It\'s Already A Favorite',
    :extuid_email_req   => 'Either extuid or email is required.',
    :friendship_not_found   => 'Whoops! Friend Not Found',
    :pass_same_as_new_pass      => 'New password is same as old password.',
    :pass_confirmation_mismatch => 'Passwords Do Not Match!'
  }


  # This was added in a effort to generate dynamic comments in api_controller.
  # But Not sure how to generate dynamic comments.
  def self.accepts_label_for(meth)
    accepts = SIGNATURE_MAP[meth][:accepts].dup
    return 'n/a' if accepts.empty?
    optonal = accepts.pop if accepts.last.is_a?(Array)
    return '(' + optonal.join(', ') + ')' if accepts.empty? # all optional
    return accepts.join(', ') if optonal.nil? # all required
    [accepts, '(' + optonal.join(', ') + ')'].join(', ')
  end

  def self.returns_label_for(meth)
    returns = SIGNATURE_MAP[meth][:returns]
    returns.is_a?(Array) ? returns.join(', ') : returns.to_s
  end

  def self.collection_label_for(meth)
    colls = SIGNATURE_MAP[meth][:collection]
    return "" if colls.blank?
    cnt = ''
    colls.each do |k, v|
      cnt << "<p>#{k.to_s} - [#{v.join(', ')}]</p>"
    end
    cnt.html_safe
  end
end
