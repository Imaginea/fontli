require 'digest'
class User
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions

  field :username, type: String
  field :full_name, type: String
  field :email, type: String
  field :hashed_password, type: String
  field :salt, type: String
  field :description, type: String
  field :website, type: String
  field :avatar_filename, type: String
  field :avatar_content_type, type: String
  field :avatar_size, type: Integer
  field :avatar_dimension, type: String
  field :extuid, type: String
  field :platform, type: String, default: 'default'
  field :iphone_token, type: String
  field :iphone_token_updated_at, type: DateTime
  field :android_registration_id, type: String
  field :wp_toast_url, type: String
  field :admin, type: Boolean, default: false
  field :expert, type: Boolean, default: false
  field :points, type: Integer, default: 5
  field :active, type: Boolean, default: true
  field :suspended_reason, type: String
  field :fav_fonts_count, type: Integer, default: 0
  field :fav_workbooks_count, type: Integer, default: 0
  field :likes_count, type: Integer, default: 0
  field :user_flags_count, type: Integer, default: 0
  field :show_in_header, type: Boolean, default: false
  field :followed_collection_ids, type: Array, default: []
  field :photos_count, type: Integer, default: 0

  index({ username: 1 }, unique: true)
  index({ email: 1 }, unique: true)

  FOTO_DIR = APP_CONFIG['user_avatar_dir']
  FOTO_PATH = File.join(FOTO_DIR, ':id/:filename_:style.:extension')
  DEFAULT_AVATAR_PATH = File.join(Rails.root, 'public/avatar_missing_:style.png')
  ALLOWED_TYPES = ['image/jpg', 'image/jpeg', 'image/png'].freeze
  PLATFORMS = %w(twitter facebook).freeze
  THUMBNAILS = { thumb: '75x75', large: '150x150' }.freeze
  LEADERBOARD_LIMIT = 20
  ALLOWED_FLAGS_COUNT = 3

  has_many :workbooks, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :collections # can exist even after the user is destroyed
  has_many :fonts, dependent: :destroy
  has_many :font_tags, dependent: :destroy
  has_many :fav_fonts, dependent: :destroy
  has_many :fav_workbooks, dependent: :destroy
  has_many :notifications, foreign_key: :to_user_id, dependent: :destroy, inverse_of: :to_user
  has_many :sent_notifications, class_name: 'Notification',
                                foreign_key: :from_user_id, dependent: :destroy, inverse_of: :from_user
  has_many :follows, dependent: :destroy
  has_many :my_followers, class_name: 'Follow', foreign_key: :follower_id, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :mentions, dependent: :destroy
  has_many :agrees, dependent: :destroy
  has_many :flags, dependent: :destroy
  has_many :user_flags, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :shares, dependent: :destroy
  has_many :suggestions, dependent: :destroy
  has_many :sessions, class_name: 'ApiSession', dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, on: :create
  validates :username, length: 5..15, allow_blank: true
  validates :username, format: { with: /^[A-Z0-9._-]+$/i, allow_blank: true, message: 'can only be alphanumeric with _-. chars.' }
  validates :email, format: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i, allow_blank: true
  validates :password, length: 6..15, confirmation: true, allow_blank: true
  validates :avatar_size,
            inclusion: { in: 0..(3.megabytes), message: 'should be less than 3MB' },
            if: -> { avatar? }
  validates :avatar_content_type,
            inclusion: { in: ALLOWED_TYPES, message: 'should be jpg/gif' },
            if: -> { avatar? }
  validates :email, presence: true, unless: -> { PLATFORMS.include? platform }
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :extuid, presence: true, if: -> { PLATFORMS.include? platform }

  attr_accessor :password, :password_confirmation, :avatar, :avatar_url, :friendship_state, :invite_state

  before_save :set_hashed_password
  after_save :save_avatar_to_file, :save_thumbnail
  after_destroy :delete_file
  after_save :update_device_token, if: ->(user) { user.iphone_token_changed? || user.android_registration_id_changed? }

  default_scope where(:active => true, :user_flags_count.lt => ALLOWED_FLAGS_COUNT)
  scope :non_admins, where(admin: false)
  scope :experts, where(expert: true)
  scope :leaders, non_admins.desc(:points).limit(LEADERBOARD_LIMIT)
  scope :following_collection, ->(c_id) { where(:followed_collection_ids.in => [c_id]) }

  class << self
    def [](uname)
      where(username: uname).first
    end

    def fontli
      self['fontli']
    end

    def by_id(uid)
      where(_id: uid.to_s).first
    end

    def by_extid(exid)
      where(extuid: exid.to_s).first
    end

    def by_uname_or_email(val)
      where(username: val).first || where(email: val).first
    end

    def search(uname, sort = nil, dir = nil)
      return [] if uname.blank?
      uname = Regexp.escape(uname.strip)
      res = where(username: /^#{uname}.*/i).to_a
      res << where(full_name: /^#{uname}.*/i).to_a
      res = res.flatten.uniq(&:id)
      res = res.sort { |a, b| b.send(sort) <=> a.send(sort) } if sort
      res = res.reverse if dir == 'asc'
      res
    end

    def search_autocomplete(uname, lmt = 20)
      return [] if uname.blank?
      uname = Regexp.escape(uname.strip)
      res = where(username: /^#{uname}.*/i).only(:username).limit(lmt).collect(&:username)
      res + where(full_name: /^#{uname}.*/i).only(:full_name).limit(lmt).collect(&:full_name)
    end

    # uname can be username or email
    def login(uname, pass)
      u = by_uname_or_email(uname)
      u && (u.pass_match?(pass) ? u : nil)
    end

    def api_login(uname, pass, devic_id)
      u = login(uname, pass)
      return [nil, :unable_to_login] if u.nil? # error
      sess = u.sessions.find_or_initialize_by(device_id: devic_id)
      sess.activate
    end

    def check_login_for(extuid_token)
      u = by_extid(extuid_token)
      return [nil, :user_not_found] if u.nil?
      true
    end

    def forgot_pass(email_or_uname)
      u = by_uname_or_email(email_or_uname)
      return [nil, :user_not_found] if u.nil?
      return [nil, :user_email_not_set] if u.email.blank?
      (u.password = rand_s) && u.hash_password
      saved = u.my_save(true)

      mail_params = { 'username' => u.username, 'email' => u.email, 'password' => u.password }
      AppMailer.forgot_pass_mail(mail_params).deliver if saved
      saved
    end

    def human_attribute_name(attr, opts = {})
      humanized_attrs = {
        avatar_filename: 'Filename',
        avatar_size: 'File size',
        avatar_content_type: 'File type'
      }
      humanized_attrs[attr.to_sym] || super
    end

    # list of all users who liked foto_id
    def liked_photo(foto_id, page = 1, lmt = 20)
      foto = Photo[foto_id]
      return [] if foto.nil?
      usr_ids = foto.likes.only(:user_id).collect(&:user_id)
      offst = (page.to_i - 1) * lmt
      where(:_id.in => usr_ids).skip(offst).limit(lmt)
    end

    def add_flag_for(usr_id, frm_usr_id)
      usr = where(_id: usr_id).only(:user_flags_count, :username).first
      return [nil, :user_not_found] if usr.nil?
      # don't let any user to flag the 'fontli' account
      return usr if usr.username == fontli.username
      obj = usr.send(:user_flags).build from_user_id: frm_usr_id
      obj.save ? usr.reload : [nil, obj.errors.full_messages]
    end

    def all_expert_ids
      unscoped.experts.collect(&:id)
    end

    def inactive_ids
      uids = unscoped.where(active: false).only(:id).collect(&:id)
      uids += unscoped.where(:user_flags_count.gte => ALLOWED_FLAGS_COUNT).only(:id).collect(&:id)
      uids.uniq
    end

    # users with highest no. of posts within last 15 days.
    def cached_popular
      Rails.cache.fetch('popular_users', expires_in: 1.day.seconds.to_i) do
        usr_ids = Photo.where(:created_at.gte => (Time.now - 15.days)).only(:user_id).to_a
        usr_ids = usr_ids.group_by(&:user_id).sort_by { |_uid, fotos| fotos.length }.reverse
        # users should have a minimum of 4 posts.
        usr_ids = usr_ids.collect { |uid, fotos| uid if fotos.length > 4 }.compact

        users = non_admins.where(:_id.in => usr_ids).to_a
        # Sort the users list based on order of usr_ids.
        ordered_users = []
        usr_ids.each do |uid|
          ordered_users << users.detect { |usr| usr.id == uid }
        end

        if ordered_users.length < 20
          limit_left = 20 - usr_ids.length
          ordered_users += leaders.where(:_id.nin => usr_ids).limit(limit_left).to_a
        end
        ordered_users[0..19]
      end
    end

    def recommended
      cached_popular
    end

    def random_popular(lmt = 5)
      usrs = recommended.select(&:show_in_header)
      usrs.sample(lmt)
    end
  end

  # Signup using FB/Twitter will not carry password. Also handle users
  # signin up more than once(when reinstalling the app) using FB/Twitter, gracefully.
  def api_signup
    resp = check_duplicate_signup
    return resp unless resp.nil?
    self.password ||= self.class.rand_s
    resp = my_save
    return resp if resp.is_a?(Array) # save failed
    check_friendships && send_welcome_mail!
    resp
  end

  def check_duplicate_signup
    return nil unless platform && extuid
    u = User.where(platform: platform, extuid: extuid).first
    u && [nil, :duplicate_signup]
  end

  def api_reset_pass(pass, npass, cpass)
    return [nil, :cur_pass_blank] if npass.blank?
    return [nil, :cur_pass_not_match] unless pass_match?(pass)
    return [nil, :pass_same_as_new_pass] if pass == npass
    return [nil, :pass_confirmation_mismatch] unless npass == cpass
    self.password = npass
    my_save(true)
  end

  def guest?
    username == 'guest'
  end

  def hash_password(pass = nil)
    self.salt ||= generate_rand
    pass ||= self.password
    Digest::HMAC.hexdigest(pass, self.salt, Digest::SHA1)
  end

  def pass_match?(pass)
    hashed_password == hash_password(pass)
  end

  def avatar=(file)
    return nil if file.nil?
    return delete_avatar if file.blank? # remove profic pic
    @avatar = file.path # temp file path
    self.avatar_filename = file.original_filename.to_s
    self.avatar_content_type = file.content_type.to_s
    self.avatar_size = file.size.to_i
    self.avatar_dimension = get_geometry(file)
  end

  def delete_avatar
    delete_file if valid?
    self.avatar_filename = nil
    self.avatar_content_type = nil
    self.avatar_size = nil
    self.avatar_dimension = nil
    true
  end

  def avatar_url=(img_url)
    io = open(URI.parse(img_url))
    # define original_filename meth on io, dynamically
    def io.original_filename
      base_uri.path.split('/').last
    end
    self.avatar = (io.original_filename.blank? ? nil : io)
  rescue Exception => ex
    puts ex.message
    Rails.logger.info "Error while parsing avatar: #{ex.message}"
  ensure
    io.close if io
    @avatar_url = img_url
  end

  def path(style = :original)
    return def_avatar_path(style) unless avatar?
    fpath = FOTO_PATH.dup
    fname = avatar_filename
    fpath.sub!(/:id/, id.to_s)
    fpath.sub!(/:filename/, fname.gsub(File.extname(fname), '').to_s)
    fpath.sub!(/:style/, style.to_s)
    fpath.sub!(/:extension/, extension)
    fpath
  end

  def url(style = :original)
    pth = path(style)
    pth = File.exist?(pth) ? pth : path
    pth = pth.sub("#{Rails.root}/public", '')
    File.join(request_domain, pth)
  end

  def url_thumb
    url(:thumb)
  end

  def url_large
    url(:large)
  end

  def user_id
    id.to_s
  end

  def delete_photo(foto_id)
    foto = photos.where(_id: foto_id).first
    !foto.nil? && foto.destroy
  end

  def follow_user(usr_id)
    f = follows.new(follower_id: usr_id)
    f.my_save(true)
  end

  def unfollow_friend(frn_id)
    f = follows.where(follower_id: frn_id).first
    return [nil, :friendship_not_found] if f.nil?
    !f.destroy.nil?
  end

  def following?(usr)
    frnship = follows.where(follower_id: usr.id).first
    !frnship.nil?
  end

  # to check if the user is a friend_of_current_user.
  def my_friend?
    return 'n/a' if me?
    current_user.following?(self)
  end

  # friends should be a array of hash with full_name, email, extuid, account_type
  def invite_all(frnds)
    results = frnds.collect do |hsh|
      invite = invites.build(hsh)
      invite.save || invite.error_resp
    end
    errors = results.select { |res| res != true }
    errors.blank? || [nil, errors]
  end

  def invites_and_friends
    frnd_ids = friend_ids
    frnd_ids << id # consider the current_user as a friend
    all_usrs = User.where(admin: false).to_a
    all_usrs.each do |usr|
      usr.invite_state = frnd_ids.include?(usr.id) ? 'Friend' : 'User'
    end
    invites.to_a + all_usrs
  end

  # get a collection of FB/Twitter friends hash(id, name) and
  # populate the invite state(Friend/User/Invited/None) for each of them
  def populate_invite_state(frnds, platform)
    conds = { :platform => platform, :extuid.in => frnds.collect { |f| f['id'] } }
    invits = invites.where(conds).only(:extuid).to_a.group_by(&:extuid)
    frn_ids = friend_ids
    all_usrs = User.where(conds.merge(admin: false)).only(:extuid, :id).to_a.group_by(&:extuid)

    # populate invite_state for the friends collection
    frnds.each do |f|
      extid = f['id']
      if invits[extid]
        f['invite_state'] = 'Invited'
      elsif all_usrs[extid].nil?
        f['invite_state'] = 'None'
      elsif u = all_usrs[extid]
        state = frn_ids.include?(u.first.id) ? 'Friend' : 'User'
        f['invite_state'] = state
        f['user_id'] = u.first.id
      end
      f['invite_state'] ||= '' # fallback
    end
    frnds
  end

  def friend_ids
    @follws ||= follows.to_a
    @follws.collect(&:follower_id)
  end

  def friends
    @frnds ||= User.where(:_id.in => friend_ids)
  end

  def follows_count
    @follows_count ||= friends.count
  end

  def followers
    @my_follwrs ||= Follow.where(follower_id: id).to_a
    @fllwrs ||= User.where(:_id.in => @my_follwrs.collect(&:user_id))
  end

  def followers_count
    @followrs_count ||= followers.count
  end

  # checks friendships of all frnds with the current_user(self)
  def populate_friendship_state(frnds)
    # hash map lookup is faster than array
    my_frnds = friends.only(:id).to_a.group_by(&:id)
    frnds.each do |f|
      next if f.id == id # nil, if current_user
      f.friendship_state = my_frnds.key?(f.id) ? 'Yes' : 'No'
    end
    frnds
  end

  def mentions_list(foto_id = nil)
    mlist = friends.only(:id, :username, :full_name).to_a
    if (foto = Photo.where(_id: foto_id).first)
      uids = foto.comments.only(:user_id).collect(&:user_id)
      unless uids.empty?
        mlist << User.where(:_id.in => uids).only(:id, :username, :full_name).to_a
      end
    end
    mlist.flatten.uniq(&:username)
  end

  def my_photos(page = 1, lmt = 20)
    @my_photos ||= photos.recent(lmt).skip(page_offset(page, lmt)).to_a
  end

  def popular_photos(page = 1, lmt = 20)
    @popular_photos ||= photos.desc(:likes_count).limit(lmt).skip(page_offset(page, lmt)).to_a
  end

  def my_workbooks(page = 1, lmt = 20)
    workbooks.only(:id, :title).recent(lmt).skip(page_offset(page, lmt)).to_a
  end

  def fav_photos(page = 1, lmt = 20)
    Photo.where(:id.in => fav_photo_ids).limit(lmt).skip(page_offset(page, lmt)).desc(:created_at).to_a
  end

  def spotted_photos(page = 1, lmt = 20)
    foto_ids = fonts.only(:photo_id).collect(&:photo_id)
    return [] if foto_ids.empty?
    Photo.where(:_id.in => foto_ids).limit(lmt).skip(page_offset(page, lmt)).desc(:created_at)
  end

  def my_fonts(page = 1, lmt = 20)
    fonts.limit(lmt).skip(page_offset(page, lmt))
  end

  def my_fav_fonts(page = 1, lmt = 20)
    fnt_ids = fav_font_ids
    return [] if fnt_ids.empty?
    Font.where(:id.in => fnt_ids).limit(lmt).skip(page_offset(page, lmt)).desc(:created_at)
  end

  # return count of favorite fonts
  def fonts_count
    fav_fonts_count
  end

  def photo_ids
    @photo_ids ||= photos.only(:id).collect(&:id)
  end

  # count of fonts tagged
  def my_fonts_count
    @my_fonts_count ||= fonts.count
  end

  def fav_photo_ids
    @fav_foto_ids ||= likes.only(:photo_id).collect(&:photo_id)
  end

  def fav_font_ids
    @fav_font_ids ||= fav_fonts.only(:font_id).collect(&:font_id)
  end

  def commented_photo_ids
    @commted_foto_ids ||= comments.only(:photo_id).collect(&:photo_id)
  end

  def comments_count
    @comments_cnt ||= comments.count
  end

  def notifications_count
    notifications.unread.count
  end

  def notifs_all_count
    @notifs_cnt ||= notifications.count
  end

  def my_updates(pge = 1, lmt = 20)
    # find out all possible inactive (notifiable) items
    inactv_uids = User.inactive_ids
    inactv_pids = Photo.flagged_ids
    inactv_lids = Like.where(:photo_id.in => inactv_pids).only(&:id).collect(&:id)
    inactv_cids = Comment.where(:photo_id.in => inactv_pids).only(&:id).collect(&:id)
    inactv_mids = Mention.where(:mentionable_id.in => inactv_pids + inactv_cids).only(&:id).collect(&:id)
    inactv_fids = Font.where(:photo_id.in => inactv_pids).only(&:id).collect(&:id)
    inactv_ftids = FontTag.where(:font_id.in => inactv_fids).only(&:id).collect(&:id)
    inactv_aids = Agree.where(:font_id.in => inactv_fids).only(&:id).collect(&:id)
    blacklst_ids = inactv_pids + inactv_lids + inactv_cids + inactv_mids + inactv_ftids + inactv_aids

    notifs = notifications.where(:from_user_id.nin => inactv_uids, :notifiable_id.nin => blacklst_ids).skip(page_offset(pge, lmt)).limit(lmt).to_a
    # mark all notifications as read, on page 1
    notifications.unread.update_all(unread: false)
    notifs
  end

  # updates on friend's activity, grouped by friend_id
  def network_updates
    frn_ids = friend_ids
    tspan = 1.week.ago
    return [] if frn_ids.empty?
    blacklst_uids = User.inactive_ids

    opts = { :user_id.in => frn_ids - blacklst_uids, :created_at.gt => tspan }
    # filter out activity on current_user photos.
    foto_ids = photo_ids
    fnt_ids = Font.where(:photo_id.in => foto_ids).only(:id).collect(&:id)

    blacklst_fids = (foto_ids + Photo.flagged_ids).uniq
    liks = Like.where(opts.merge(:photo_id.nin => blacklst_fids)).desc(:created_at).to_a
    ftgs = FontTag.where(opts.merge(:font_id.nin => fnt_ids)).desc(:created_at).to_a
    flls = Follow.where(opts.merge(:follower_id.nin => [id] + blacklst_uids)).desc(:created_at).to_a
    favs = FavFont.where(opts).desc(:created_at).to_a
    (liks + ftgs + flls + favs).sort_by(&:created_at).reverse
  end

  def display_name
    full_name || username
  end

  # current_user.can_follow?(other_user)
  def can_follow?(usr)
    return false if usr.id == id # Same user
    !friend_ids.include?(usr.id)
  end

  def can_flag?(usr)
    return false if usr.id == id # Same user
    flags.where(from_user_id: usr.id).first.nil?
  end

  def can_follow_collection?(collection)
    !followed_collection_ids.include?(collection.id)
  end

  def follow_collection(collection)
    return false unless can_follow_collection?(collection)
    followed_collection_ids << collection.id
    save
  end

  def unfollow_collection(collection)
    followed_collection_ids.delete(collection.id)
    save
  end

  def spotted_on?(foto)
    @spotted_foto_ids ||= fonts.only(:photo_id).collect(&:photo_id)
    @spotted_foto_ids.include?(foto.id)
  end

  def spotted_font(foto)
    fonts.where(photo_id: foto.id).first
  end

  def self.rand_s(length = 8)
    rand(36**length).to_s(36)
  end

  private

  def generate_rand(length = 8)
    SecureRandom.base64(length)
  end

  def set_hashed_password
    return true if password.blank?
    self.hashed_password = hash_password
  end

  def save_avatar_to_file
    return true if avatar.nil?
    ensure_dir(FOTO_DIR)
    ensure_dir(File.join(FOTO_DIR, id.to_s))
    Rails.logger.info "Saving file: #{path}"
    FileUtils.cp(avatar, path)
    true
  end

  def ensure_dir(dirname = nil)
    raise 'directory path cannot be empty' if dirname.nil?
    FileUtils.mkdir(dirname) unless File.exist?(dirname)
  end

  def delete_file
    return true unless avatar?
    Rails.logger.info 'Deleting thumbnails..'
    remove_dir(File.join(FOTO_DIR, id.to_s))
    true
  end

  def remove_dir(dirname = nil)
    raise 'directory path cannot be empty' if dirname.nil?
    FileUtils.remove_dir(dirname, true) if File.exist?(dirname)
  end

  def save_thumbnail
    return true if avatar.nil?
    image_manipulation = ImageManipulation.new(self)
    image_manipulation.save_thumbnail(path, avatar_dimension)
    # reset the avatar so that any save on this object
    # will not trigger the thumbnail creation twice.
    @avatar = nil
    true
  end

  def get_geometry(file)
    `identify -format %wx%h #{file.path}`.strip
  end

  # create friendships b/w all users invited me.
  def check_friendships
    invites = if platform.blank?
                Invite.where(email: email)
              else # FB/Twitter user
                Invite.where(platform: platform, extuid: extuid)
              end
    invites.to_a.each { |invit| invit.mark_as_friend(self) }

    # Also make fontli user as a mutual friend.
    fntli = User.fontli
    follows.create(follower_id: fntli.id)
    fntli.follows.create(follower_id: id)
    true
  end

  def send_welcome_mail!
    return if email.blank?
    AppMailer.welcome_mail(self).deliver
  end

  def me?
    current_user.id.to_s == id.to_s
  end

  def avatar?
    !avatar_filename.blank?
  end

  def def_avatar_path(style = :original)
    DEFAULT_AVATAR_PATH.gsub(/:style/, style.to_s)
  end

  def extension
    File.extname(avatar_filename).gsub(/\.+/, '')
  end

  def recent_photos
    photos.limit(8).to_a
  end

  def update_device_token
    User.where(:id.ne => id, :android_registration_id => android_registration_id).update_all(android_registration_id: nil) if android_registration_id_changed?
    User.where(:id.ne => id, :iphone_token => iphone_token).update_all(iphone_token: nil) if iphone_token_changed?
  end

  def page_offset(page = 1, lmt = 20)
    (page.to_i - 1) * lmt
  end
end
