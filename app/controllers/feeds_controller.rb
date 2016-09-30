class FeedsController < ApplicationController
  skip_before_filter :login_required, :only => [:show, :fonts, :permalink, :profile, :popular, :search, :recent_fonts, :search_autocomplete, :show_font]

  def index
    @photos = Photo.feeds_for(current_user, (params[:page] || 1)).to_a
    preload_photos_my_likes_comments
  end

  def show
    @photo = Photo.find(params[:id])
    preload_photo_associations
    render 'show', :layout => false
  end

  def permalink
    url = Base64.urlsafe_decode64(URI.unescape(params[:url]))
    klass, id = url.split('_')
    @photo, @perma = klass.constantize.find(id.to_s), true
    preload_photo_associations
    @meta_title = 'Photo Detail'
    render 'show', :layout => 'plain'
  rescue Exception => e
    Rails.logger.error { "#{e.message} #{e.backtrace.join("\n")}" }
    render :file => 'public/404', :status => '404', :layout => false, :format => 'html'
  end

  def sos
    @photos = Photo.sos(params[:page] || 1).to_a
    preload_photos_my_likes_comments
  end

  def fonts
    @fonts = Photo[params[:id]].fonts.desc(:created_at).to_a
    render :partial => 'spotted_pop', :layout => false
  end

  def recent_fonts
    @fonts = Font.popular.to_a
  end

  def show_font
    @font = Font[params[:font_id]]
    # @details = Rails.cache.fetch("font_family_details_#{params[:family_id]}") do
    #  FontFamily.family_details(params[:family_id])
    # end

    case params[:type]
    when 'fav'
      @users = @font.fav_users(params[:page], 18).to_a
    else
      opts = { :family_id => params[:family_id], :page => params[:page] }
      @photos = Font.tagged_photos_for(opts, 18).to_a
      preload_photos_my_likes_comments
    end
    @meta_title = 'Font Detail'
  end

  def profile
    @user = User.by_id(params[:user_id]) || current_user
    page = params[:page] || 1
    offst = (page.to_i - 1) * 18

    case params[:type]
    when 'like'
      @photos = @user.fav_photos(page, 18)
      preload_photos_my_likes_comments(:skip_likes => true)
    when 'fav_font'
      @fonts = @user.my_fav_fonts(page, 18).to_a
      #preload_fonts_photos # this is more tricky
    when 'spotted'
      @photos = @user.spotted_photos(page, 18).to_a
      preload_photos_my_likes_comments
    when 'followers'
      @users = @user.followers.limit(18).skip(offst).to_a
    when 'follows'
      @users = @user.friends.limit(18).skip(offst).to_a
    else
      @photos = @user.photos.recent(18).skip(offst).to_a
      preload_photos_my_likes_comments
    end
  end

  def popular
    case params[:type]
    when 'post'
      @photos = Photo.popular
      preload_photos_my_likes_comments
    when 'font'
      @fonts = Font.api_recent
    else
      @users = User.recommended
    end
  end

  def post_feed
    return if request.get?
    @photo = current_user.photos.unpublished.first
    @photo ||= current_user.photos.new(:caption => Photo::DEFAULT_TITLE)
    @photo.data = params[:photo]
    @status = @photo.save
    redirect_to :action => "index", :photo_id => @photo.id
  end

  def publish_feed
    return if request.get?
    @photo = current_user.photos.unpublished.find(params[:id])
    @photo.caption = params[:caption]
    @photo.crop = params[:crop]
    @photo.created_at = Time.now.utc
    if @photo.save
    redirect_to feeds_url, :notice => "Posted to feed, successfully."
    end
  end

  def socialize_feed
    @photo = Photo.find(params[:id])
    meth_name = "#{whitelisted_feed}_feed".to_sym
    self.method(meth_name).call
    @photo.reload # to read the new likes_count/comments_count
    render meth_name
  end

  def follow_user
    @user = User.find(params[:id])
    current_user.follows.new(:follower_id => @user.id).save
  end

  def unfollow_user
    @user = User.find(params[:id])
    current_user.follows.where(:follower_id => @user.id).first.destroy
    render 'follow_user'
  end

  def detail_view
    @foto = Photo.find(params[:id])
  end

  def get_mentions_list
    @foto = Photo.find(params[:id])
    @mentions_list = current_user.mentions_list(@foto.id)
  end

  def search_autocomplete
    term, lmt = params[:term], 7
    users = User.search_autocomplete(term, lmt)
    posts = Photo.search_autocomplete(term, lmt)
    fonts = Font.search_autocomplete(term, lmt)

    # users and fonts takes precedence over posts
    results = (users + fonts + posts).uniq.first(lmt)
    render :json => results.sort_by(&:length)
  end

  def search
    term = params[:search]
    @users = User.search(term)
    @posts = Photo.search(term)
    # Return only uniq fonts by family_id/subfont_id
    @fonts = Font.search(term).uniq(&:key)
  end

  private

  def like_feed
    lke = @photo.likes.new(:user_id => current_user.id)
    lke.save
  end

  def unlike_feed
    lke = @photo.likes.where(:user_id => current_user.id).first
    lke.destroy
  end

  def comment_feed
    @cmt = @photo.comments.new(
      :user_id => current_user.id,
      :body => params[:comment]
    )
    @status = @cmt.save
  end

  def share_feed
  end

  def flag_feed
    flg = @photo.flags.new(:user_id => current_user.id)
    flg.save
  end

  def unflag_feed
    flg = @photo.flags.where(:user_id => current_user.id).first
    flg.destroy
  end

  def remove_feed
    @status = @photo.destroy
  end

  # loads all likes and comments with associated users for a foto.
  def preload_photo_associations(foto = nil)
    foto ||= @photo
    @likes = foto.likes.includes(:user).desc(:created_at).to_a
    lkd_usr_ids = @likes.collect(&:user_id)
    @comments = foto.comments.includes(:user).desc(:created_at).to_a
    cmt_usr_ids = @comments.collect(&:user_id)

    unless (lkd_usr_ids + cmt_usr_ids).empty?
      usrs = User.where(:_id.in => (lkd_usr_ids + cmt_usr_ids)).only(:id, :username, :avatar_filename).to_a
      @users_map = usrs.group_by(&:id)
    end
  end

  def preload_photos_my_likes_comments(opts={})
    f_ids, user = @photos.collect(&:id), @user

    if f_ids.any?
      @users_map = User.where(:_id.in => @photos.collect(&:user_id)).group_by(&:id)
      @my_lks = @my_cmts = {}
      return true
    end
  end

  def whitelisted_feed
    return params[:modal] if %w(like unlike comment share flag unflag remove).include? params[:modal]

    raise StandardError, "unexpected feed: #{params[:modal]}"
  end
end
