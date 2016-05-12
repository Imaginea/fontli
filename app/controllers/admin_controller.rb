class AdminController < ApplicationController

  skip_before_filter :login_required # skip the regular login check
  before_filter :admin_required # use http basic auth
  helper_method :sort_column, :sort_direction
  #Add option to send generic push notifications.

  def index
    @admin_presenter = AdminPresenter.new
  end

  def users
    @page, @lmt = [(params[:page] || 1).to_i, 10]
    offst       = (@page - 1) * @lmt
    if params[:search].to_s.strip.present?
      @users = User.search(params[:search], sort_column, sort_direction)
    else
      @users = User.non_admins
      @users = if ["photos_count", "follows_count"].include?(sort_column)
                 users = @users.sort_by(&"#{sort_column}".to_sym)
                 users = users.reverse if sort_direction == 'desc'
                 users.drop(offst).first(@lmt)
               else
                 @users.order_by(sort_column => sort_direction).skip(offst).limit(@lmt)
               end
      @users_cnt = User.non_admins.count
      @max_page  = (@users_cnt / @lmt.to_f).ceil
    end
    @suspend_user = true
    @delete_user = true
  end

  def suspend_user
    @res = User.where(:_id => params[:id]).first.update_attribute(:active, false)
    opts = @res ? {:notice => 'User account suspended.'} : {:alert => 'Couldn\'t suspend. Please try again!'}
    redirect_to '/admin/users', opts
  end

  def delete_user
    @res = User.unscoped.where(:_id => params[:id]).first.destroy
    opts = @res ? {:notice => 'User account deleted.'} : {:alert => 'Couldn\'t delete. Please try again!'}
    redirect_to '/admin/users', opts
  end

  def suspended_users
    @page, @lmt = [1, 10]
    @users = User.unscoped.where(:active => false).order_by(sort_column => sort_direction).to_a
    @title, params[:search] = ['Suspended Users', 'Not Implemented']
    @activate_user = true
    @delete_user = true
    render :users
  end

  def activate_user
    @res = User.unscoped.where(:_id => params[:id]).first.update_attribute(:active, true)
    opts = @res ? {:notice => 'User account activated.'} : {:alert => 'Couldn\'t activate. Please try again!'}
    redirect_to '/admin/users', opts
  end

  def photos
    @page, @lmt = [(params[:page] || 1).to_i, 10]
    offst = (@page - 1) * @lmt
    if !params[:search].to_s.strip.blank?
      @fotos = Photo.where(:caption => /^#{params[:search]}.*/i).order_by(sort_column => sort_direction).to_a
    elsif !params[:user_id].to_s.strip.blank?
      @fotos = Photo.where(:user_id => params[:user_id]).order_by(sort_column => sort_direction).to_a
      @select_photo = true
      params[:search] = 'Not Implemented'
    elsif params[:home].to_s == 'true'
      @title = 'Homepage Photos'
      @fotos = Photo.for_homepage.to_a
      @unselect_photo = true
      params[:search] = 'Not Implemented'
    else
      @fotos = Photo.all.order_by(sort_column => sort_direction).skip(offst).limit(@lmt)
      @fotos_cnt = Photo.count
      @max_page  = (@fotos_cnt / @lmt.to_f).ceil
      @select_photo = true
    end
    @delete_photo = true
  end

  def collections
    @collections = Collection.all.to_a
  end

  def create_collection
    opts = params[:collection]
    collection = Collection.new(name: opts[:name], description: opts[:description])
    if collection.save
      flash[:notice] = 'Created successfully'
    else
      flash[:alert] = collection.errors.full_messages.join('<br/>')
    end
    redirect_to '/admin/collections'
  end

  def activate_collection
    collection = Collection.find(params[:id])
    if collection.update_attribute(:active, true)
      flash[:notice] = 'Activated successfully'
    else
      flash[:alert] = 'Activation failed'
    end
    redirect_to '/admin/collections'
  end

  def photos_list_for_collection
    @collections = Collection.all.to_a
    page = params[:page] || 1
    offst = (page - 1) * 50
    @photos = Photo.only(:id, :data_filename, :collection_ids).
      desc(:created_at).skip(offst).limit(50)
  end

  def flagged_users
    @page, @lmt = [1, 10]
    params[:sort] ||= 'user_flags_count'
    @users = User.unscoped.where(:user_flags_count.gte => User::ALLOWED_FLAGS_COUNT).order_by(sort_column => sort_direction).to_a
    @title, params[:search] = ['Flagged Users', 'Not Implemented']
    @unflag_user = true
    @delete_user = true
    render :users
  end

  def unflag_user
    usr = User.unscoped.where(:_id => params[:id]).first
    res = usr.user_flags.destroy_all
    res = res && usr.update_attribute(:user_flags_count, 0)
    opts = res ? {:notice => 'User account unflagged.'} : {:alert => 'Couldn\'t unflag. Please try again!'}
    redirect_to '/admin/flagged_users', opts
  end

  def flagged_photos
    @page, @lmt = [1, 10]
    params[:sort] ||='flags_count'
    @fotos = Photo.unscoped.where(:flags_count.gte => Photo::ALLOWED_FLAGS_COUNT).order_by(sort_column => sort_direction).desc(:flags_count).to_a
    @title, params[:search] = ['Flagged Photos', 'Not Implemented']
    @unflag_photo = true
    @delete_photo = true
    render :photos
  end

  def unflag_photo
    @res = Photo.unscoped.where(:_id => params[:id]).first.flags.destroy_all
  end

  def sos
    @page, @lmt = [(params[:page] || 1).to_i, 10]
    offst = (@page - 1) * @lmt
    @title, conds = ['SoS photos', {:font_help => true, :sos_approved => true}]
    if params[:req] == 'true'
      @title = 'SoS photos waiting for approval'
      conds = conds.merge(:sos_approved => false)
      params[:sort] ||= 'sos_requested_at'
      @approve_sos = true
    else
      params[:sort] ||= 'sos_approved_at'
    end

    unless params[:search].to_s.strip.blank?
      conds = conds.merge(:caption => /^#{params[:search]}.*/i)
      @fotos = Photo.where(conds).order_by(sort_column => sort_direction).to_a
    else
      @fotos = Photo.where(conds).order_by(sort_column => sort_direction).skip(offst).limit(@lmt)
      @fotos_cnt = Photo.where(conds).count
      @max_page  = (@fotos_cnt / @lmt.to_f).ceil
    end
    @delete_photo = true
    render :photos
  end

  def approve_sos
    @res = Photo[params[:photo_id]].update_attribute(:sos_approved, true) rescue false
  end

  def delete_photo
    @res = Photo.unscoped.where(:_id => params[:id]).first.destroy rescue false
  end

  def select_photo
    unselect = params[:select].to_s == 'false'
    @res = Photo[params[:id]].update_attribute(:show_in_homepage, !unselect) rescue false
  end

  def popular_users
    @users = User.recommended
  end

  def popular_photos
    @photos = Photo.popular
  end

  def popular_fonts
    fonts = Font.api_recent
    @photos = fonts.collect do |fnt|
      Font.tagged_photos_popular(fnt.family_id).to_a
    end.flatten
    @font_page = true
    render :action => 'popular_photos'
  end

  def select_for_header
    klass = Kernel.const_get(params[:modal])
    obj = klass.find(params[:id])
    obj.show_in_header = params[:status] == 'true'
    obj.save! && render(:nothing => true)
  end

  def expire_popular_cache
    Stat.expire_popular_cache!
    redirect_to :back
  end

  def update_stat
    Stat.current.update_attributes(:app_version => params[:version])
    redirect_to :action => :index
  end

  # TODO: batch process and or add more criterias to user search.
  def send_push_notifications
    if params[:message].blank?
      flash.now[:alert] = 'Message can\'t be blank' if request.post?
      return
    end

    users = User.non_admins.where(:iphone_token.ne => nil)
    users.each do |user|
      opts = { :badge => user.notifications.unread.count,
               :alert => params[:message],
               :sound => true }
      APN.notify_async(user.iphone_token, opts)
    end
    
    redirect_to '/admin', :notice => "Notified #{users.length} users."
  end

private
  def sort_column
    params[:sort].blank? ? "created_at" : params[:sort]
  end

  def sort_direction
    params[:direction].blank? ? "desc" : params[:direction]
  end
end
