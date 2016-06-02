class Photo
  include Mongoid::Document
  include MongoExtensions
  include Scorable

  field :caption, :type => String
  field :data_filename, :type => String
  field :data_content_type, :type => String
  field :data_size, :type => Integer
  field :data_dimension, :type => String
  field :latitude, :type => Float
  field :longitude, :type => Float
  field :address, :type => String
  field :sos_approved, :type => Boolean, :default => false
  field :font_help, :type => Boolean, :default => false
  field :likes_count, :type => Integer, :default => 0
  field :comments_count, :type => Integer, :default => 0
  field :flags_count, :type => Integer, :default => 0
  field :fonts_count, :type => Integer, :default => 0
  field :created_at, :type => Time
  field :position, :type => Integer
  field :sos_requested_at, :type => Time
  field :sos_requested_by, :type => String
  field :sos_approved_at, :type => Time
  field :show_in_homepage, :type => Boolean, :default => false
  field :show_in_header, :type => Boolean, :default => false

  belongs_to :user, :index => true
  belongs_to :workbook, :index => true, :counter_cache => true
  has_many :fonts, :autosave => true, :dependent => :destroy
  has_many :likes, :dependent => :destroy
  has_many :flags, :dependent => :destroy
  has_many :shares, :dependent => :destroy
  has_many :comments, :autosave => true, :dependent => :destroy
  has_many :mentions, :as => :mentionable, :autosave => true, :dependent => :destroy
  has_many :hash_tags, :as => :hashable, :autosave => true, :dependent => :destroy
  has_and_belongs_to_many :collections, :autosave => true

  FOTO_DIR = APP_CONFIG['photo_dir']
  FOTO_PATH = File.join(FOTO_DIR, ':id/:style.:extension')
  ALLOWED_TYPES = ['image/jpg', 'image/jpeg', 'image/png']
  DEFAULT_TITLE = 'Yet to publish'
  # :medium version is used only on the web pages.
  THUMBNAILS = { :large => '640x640', :medium => '320x320', :thumb => '150x150' }
  # NOTE: WE still 320x version for web pages.
  # We can delay generating versions that are not immediately required?
  # TODO:: Check with mob team on why three versions?
  # We may have to rename all current url_medium refs to url_web
  # CHECK: Do we need new iOS build to support new versions?
  NEW_THUMBNAILS = { :large => '1080x1080', :medium => '750x750', :thumb => '640x640', :web => '320x320' }
  POPULAR_LIMIT = 20
  ALLOWED_FLAGS_COUNT = 5

  AWS_API_CONFIG = Fontli.load_erb_config('aws_s3.yml')[Rails.env].symbolize_keys
  AWS_STORAGE = AWS_API_CONFIG.delete(:use_s3) || Rails.env.to_s == 'production'
  AWS_BUCKET = AWS_API_CONFIG.delete(:bucket)
  AWS_PATH = ":id_:style.:extension"
  AWS_STORAGE_CONNECTIVITY =  Fog::Storage.new(AWS_API_CONFIG)
  AWS_SERVER_PATH = "http://s3.amazonaws.com/#{AWS_BUCKET}/"

  validates :caption, :length => 2..500, :allow_blank => true
  validates :data_filename, :presence => true
  validates :data_size,
    :inclusion => { :in => 0..(5.megabytes), :message => "should be less than 5MB" },
    :allow_blank => true
  validates :data_content_type,
    :inclusion => { :in => ALLOWED_TYPES, :message => 'should be jpg/png' },
    :allow_blank => true

  attr_accessor :data, :crop_x, :crop_y, :crop_w, :crop_h, :from_api, :liked_user, :commented_user, :cover

  default_scope where(:caption.ne => DEFAULT_TITLE, :flags_count.lt => ALLOWED_FLAGS_COUNT) # default filters
  scope :recent, lambda { |cnt| desc(:created_at).limit(cnt) }
  scope :unpublished, where(:caption => DEFAULT_TITLE)
  scope :sos_requested, where(:font_help => true, :sos_approved => false).desc(:sos_requested_at)
  scope :sos_approved, where(:font_help => true, :sos_approved => true)
  # Instead mark the photo as inactive when sos requested(to filter it across), and activate during approval
  # But even the user who uploaded it won't be able to see it. Need confirmation on this.
  scope :non_sos_requested, where(:sos_approved => true)
  scope :geo_tagged, where(:latitude.ne => 0, :longitude.ne => 0)
  scope :all_popular, Proc.new { where(:likes_count.gt => 1, :created_at.gt => 7.days.ago).desc(:likes_count) }
  scope :for_homepage, where(:show_in_homepage => true).desc(:created_at)

  #before_save :crop_file # we receive only the cropped images from client.
  before_save   :set_sos_approved_at
  after_create  :populate_mentions
  after_save    :send_sos_requested_mail, if: lambda { |photo| photo.font_help_changed? && photo.font_help? }
  after_save    :save_data_to_file, :save_thumbnail, :save_data_to_aws
  after_destroy :delete_file
  after_save    :update_user_photos_count, :if => lambda { |photo| photo.caption_changed? || photo.flags_count? }
  after_destroy :update_user_photos_count
  
  class << self
    def [](foto_id)
      self.where(:_id => foto_id.to_s).first
    end

    # mostly used in scripts to batch process the photos
    def in_batches(batch_size = 1000, conds = nil)
      conds ||= { :_id.ne => nil }
      scpe = self.where(conds)
      fetched_cnt = 0

      while scpe.count > fetched_cnt do
        fotos = scpe.asc(:created_at).skip(fetched_cnt).limit(batch_size).to_a
        fetched_cnt += fotos.length

        yield fotos
        puts "Processed #{fetched_cnt}/#{scpe.count} records."
      end
    end

    def human_attribute_name(attr, opts = {})
      humanized_attrs = {
        :data_filename => 'Filename',
        :data_size     => 'File size',
        :data_content_type => 'File type'
      }
      humanized_attrs[attr.to_sym] || super
    end

    def save_data(opts = {})
      def_opts = { :caption => DEFAULT_TITLE, :from_api => true }
      opts = def_opts.update opts
      foto = self.unpublished.where(:user_id => opts[:user_id]).first
      # just update the data, where there's one - unpublished
      unless foto.nil?
        foto.update_attributes(opts) if opts[:data]
        return foto
      end
      Rails.logger.info "Foto created at #{Time.now.utc} --#{`date`}--#{Time.zone.now}- with options - #{opts[:user_id].inspect}"
      self.new(opts).my_save
    end

    def publish(opts)
      foto = self.unpublished.where(:_id => opts.delete(:photo_id)).first
      return [nil, :photo_not_found] if foto.nil?
      usr_id = opts.delete(:user_id)
      opts[:created_at] = Time.now.utc
      if opts[:font_help].to_s == 'true'
        opts[:sos_requested_at] = Time.now.utc
        opts[:sos_requested_by] = usr_id.to_s
      end
      resp = foto.update_attributes(opts)
      resp ? foto : [nil, foto.errors.full_messages]
    end

    def add_like_for(photo_id, usr_id)
      opts = { :user_id => usr_id }
      self.add_interaction_for(photo_id, :likes, opts)
    end

    def unlike_for(photo_id, user_id)
      if photo = self[photo_id]
        photo.likes.where(:user_id => user_id).first.try(:destroy)
        photo.reload
      else
        [nil, :record_not_found]
      end
    end

    def add_flag_for(photo_id, usr_id)
      opts = { :user_id => usr_id }
      self.add_interaction_for(photo_id, :flags, opts)
    end

    def add_share_for(photo_id, usr_id)
      opts = { :user_id => usr_id, :return_bool => true }
      self.add_interaction_for(photo_id, :shares, opts)
    end

    # opts - photo_id, body, user_id, font_tags, hashes
    # creates the font_tags on the photo and then create the comment
    def add_comment_for(opts)
      foto = self[opts.delete(:photo_id)]
      return [nil, :photo_not_found] if foto.nil?
      ftags = opts.delete(:font_tags) || []
      # group by unique fonts
      ftags = ftags.group_by { |f| f[:family_unique_id] + f[:family_id] + f[:subfont_id].to_s }
      fnt, valid_font = [nil, true]
      opts[:font_tag_ids] = ftags.collect do |key, fnts|
        f, coords = [ fnts.first, fnts.collect { |hsh| hsh[:coords] } ]
        f[:user_id] = opts[:user_id]
        fnt, tag_ids = build_font_tags(f, foto, coords)
        break unless valid_font = (fnt.new_record? || fnt.save)
        tag_ids
      end.flatten
      return [nil, fnt.errors.full_messages] unless valid_font

      (opts.delete(:hashes) || []).each { |hsh_tg_opts| foto.hash_tags.build hsh_tg_opts }
      foto.comments.build(opts)
      foto.save ? foto.reload : [nil, foto.errors.full_messages]
    end
    
    def feeds_for(usr = nil, page = 1, lmt = 15)
      usr ||= current_user
      frn_ids = usr.friend_ids + [usr.id]
      collection_ids = usr.followed_collection_ids
      offst = (page.to_i - 1) * lmt
      Photo.or({:user_id.in => frn_ids}, {:collection_ids.in => collection_ids, :likes_count.gt => 0}).
        desc(:created_at).skip(offst).limit(lmt)
    end

    def cached_popular
      pop_ids = Rails.cache.fetch('popular_photos', :expires_in => 1.day.seconds.to_i) do
        pops = self.all_popular.limit(POPULAR_LIMIT).pluck(:_id)
        # add recent fotos if there aren't enough populars
        if pops.length < POPULAR_LIMIT
          pops += self.recent(POPULAR_LIMIT - pops.length).pluck(:_id)
        end
        pops
      end
      self.where(:_id.in => pop_ids).desc(:likes_count, :created_at).to_a
    end

    def popular
      self.cached_popular
    end

    # return no of popular photos in random
    # assumes there are enough popular photos in DB
    def random_popular(lmt = 1)
      fotos = self.popular.select(&:show_in_header)
      fotos.shuffle.first(lmt)
    end

    def all_by_hash_tag(tag_name, pge = 1, lmt = 20)
      return [] if tag_name.blank?
      hsh_tags = HashTag.where(:name => /^#{tag_name}$/i).only(:hashable_id, :hashable_type)
      foto_ids = HashTag.photo_ids(hsh_tags)
      offst = (pge.to_i - 1) * lmt
      self.where(:_id.in => foto_ids).skip(offst).limit(lmt)
    end

    def sos(pge = 1, lmt = 20)
      #return [] if pge.to_i > 2
      offst = (pge.to_i - 1) * lmt
      sos_approved.desc(:created_at).skip(offst).limit(lmt).to_a
    end

    def check_mentions_in(val)
      regex = /\s@([a-zA-Z0-9]+\.?_?-?\$?[a-zA-Z0-9]+\b)/
      val = ' ' + val.to_s # add a space infront, to match mentions at the start.
      unames = val.to_s.scan(regex).flatten
      return [] if unames.blank?
      # return only valid users hash of id, username
      urs = User.where(:username.in => unames).only(:id, :username).to_a
      urs.collect { |u| { :user_id => u.id, :username => u.username } }
    end

    def flagged_ids
      self.unscoped.where(:flags_count.gte => ALLOWED_FLAGS_COUNT).only(:id).collect(&:id)
    end

    def search(text,sort = nil,dir = nil)
      return [] if text.blank?
      text = Regexp.escape(text.strip)
      res = self.where(:caption => /^#{text}.*/i).to_a
      res = res.sort{|a,b| a.send(sort) <=> b.send(sort)} if sort
      res = res.reverse if dir == "asc"
      res
    end

    def search_autocomplete(text, lmt=20)
      return [] if text.blank?
      text = Regexp.escape(text.strip)
      self.where(:caption => /^#{text}.*/i).only(:caption).limit(lmt).collect(&:caption)
    end
  end

  def data=(file)
    return nil if file.blank?
    @file_obj = file
    @data = file.path # temp file path
    self.data_filename = file.original_filename.to_s
    self.data_content_type = file.content_type.to_s
    self.data_size = file.size.to_i
    self.data_dimension = get_geometry(file)
  end

  def path(style =  :original)
    fpath = FOTO_PATH.dup
    fpath.sub!(/:id/, self.id.to_s)
    fpath.sub!(/:style/, style.to_s)
    fpath.sub!(/:extension/, extension)
    fpath
  end

  # returns original url, if thumb/large doesn't exist
  def url(style = :original)
    if AWS_STORAGE
      style = :large if style == :original # we don't store original in aws
      aws_url(style)
    else
      pth = self.path(style)
      pth = File.exist?(pth) ? pth : self.path
      pth = pth.sub("#{Rails.root}/public", "")
      File.join(request_domain, pth)
    end
  end

  def aws_url(style)
    "#{AWS_SERVER_PATH}#{id}_#{style}.#{extension}"
  end

  def aws_path(style= :large)
    fpath = AWS_PATH.dup
    fpath.sub!(/:id/, self.id.to_s)
    fpath.sub!(/:style/, style.to_s)
    fpath.sub!(/:extension/, extension)
    fpath
  end

  def url_thumb
    url(:thumb)
  end

  def url_large
    url(:large)
  end

  def url_medium
    url(:medium)
  end

  def crop?
    !crop_x.blank? && !crop_y.blank? && !crop_w.blank? && !crop_h.blank?
  end

  def crop=(crop_opts)
    crop_opts.each do |k, v|
      self.send("#{k.to_s}=".to_sym, v)
    end
  end

  # just build the fonts collection to ensure that
  # we don't create duplicates on validation failures.
  # fnts - Array of font hashes
  def font_tags=(fnts)
    return true if fnts.blank?
    fnts = fnts.group_by { |f| f[:family_unique_id] + f[:family_id] + f[:subfont_id].to_s }
    cur_user_id = current_user.id
    fnt_tag_ids = []
    fnts.each do |key, fonts|
      f, coords = [ fonts.first, fonts.collect { |hsh| hsh[:coords] } ]
      f[:user_id] = cur_user_id
      fnt, tag_ids = self.class.send(:build_font_tags, f, self, coords)
      fnt_tag_ids << tag_ids
    end
    # all font tags are also a comment
    self.comments.build(:user_id => cur_user_id, :font_tag_ids => fnt_tag_ids.flatten)
  end

  #hshs - Array of HashTag hashes
  def hashes=(hshs)
    return true if hshs.blank?
    hshs.each do |h|
      self.hash_tags.build(h)
    end
  end

  # Take array of collection names and populate collections
  # New collections can also be created here.
  def collection_names=(c_names)
    return true if c_names.blank?
    c_names.each do |c_name|
      next if c_name.strip.blank?
      opts = { :name => c_name, :user => current_user, :active => true }
      c = Collection.where(:name => c_name).first || Collection.create(opts)
      self.collections.concat([c])
    end
  end

  def collection_names
    self.collections.active.pluck(:name).join('||')
  end

  def add_to_collections(c_names)
    collctns = Collection.where(:name.in => c_names).to_a
    self.collections.concat(collctns)
  end

  def aspect_fit(frame_width, frame_height)
    image_width, image_height = self.data_dimension.split('x')
    ratio_frame = frame_width / frame_height
    ratio_image = image_width.to_f / image_height.to_f
    if ratio_image > ratio_frame
      image_width  = frame_width
      image_height = frame_width / ratio_image
    elsif image_height.to_i > frame_height
      image_width = frame_height * ratio_image
      image_height = frame_height
    end
    [image_width.to_i, image_height.to_i]
  end

  def username
    @usr ||= self.user
    @usr.username
  end

  def user_url_thumb
    @usr ||= self.user
    @usr.url_thumb
  end

  def top_fonts
    top_picks = self.fonts.where(:pick_status.gt => 0).to_a
    top_agreed = self.fonts.where(:agrees_count.gt => 10).to_a
    top_picks + top_agreed
  end

  def most_agreed_font
    self.fonts.desc(:agrees_count).first
  end

  # order fonts by top; pick_status -> agrees_count -> tags_count
  def fonts_ord
    fnts = self.fonts.to_a
    fnts.sort_by {|f| [-f.pick_status, -f.agrees_count, -f.tags_count] }
  end

  def liked?
    current_user.fav_photo_ids.include?(self.id)
  end

  def commented?
    current_user.commented_photo_ids.include?(self.id)
  end

  # populate recent 5 liked and 2 commented usernames for a foto.
  def populate_liked_commented_users(opts = {})
    lkd_usr_ids = [] if opts[:only_comments]
    cmt_usr_ids = [] if opts[:only_likes]
    lks_lmt = opts[:likes_limit] || 5
    cmts_lmt = opts[:comments_limit] || 2

    lkd_usr_ids ||= self.likes.desc(:created_at).limit(lks_lmt).only(:user_id).collect(&:user_id)
    cur_usr_id = lkd_usr_ids.delete(current_user.id)
    cmt_usr_ids ||= self.comments.desc(:created_at).limit(cmts_lmt).only(:user_id).collect(&:user_id)
    unless (lkd_usr_ids + cmt_usr_ids).empty?
      usrs = User.where(:_id.in => (lkd_usr_ids + cmt_usr_ids)).only(:id, :username).to_a
      usrs = usrs.group_by(&:id)
      self.liked_user = (cur_usr_id.nil? ? '' : 'You||') + lkd_usr_ids.collect { |uid| usrs[uid].first.username }.join('||')
      self.commented_user = cmt_usr_ids.collect { |uid| usrs[uid].first.username }.join('||')
    end
  end

private

  def self.add_interaction_for(photo_id, klass, opts = {} )
    photo = self[photo_id]
    return [nil, :photo_not_found] if photo.nil?

    return_bool = opts.delete(:return_bool)
    obj = photo.send(klass.to_sym).build(opts)
    obj.save ? (return_bool || photo.reload) : [nil, obj.errors.full_messages]
  end

  def self.build_font_tags(opts, foto, coords)
    find_opts = opts.dup.keep_if { |k, v| [:family_unique_id, :family_id, :subfont_id].include? k.to_sym }
    fnt = foto.fonts.find_or_initialize_by(find_opts)
    okeys = opts.keys - find_opts.keys - ['coords']
    okeys.each { |k| fnt.send("#{k}=".to_sym, opts[k]) }
    tag_ids = coords.collect do |c|
      tg = fnt.font_tags.build(:coords => c, :user_id => opts[:user_id])
      tg.id
    end
    [fnt, tag_ids]
  end

  def populate_mentions
    mnts = Photo.check_mentions_in(self.caption)
    mnts.each { |hsh| self.mentions.create(hsh) }
    true
  end

  def save_data_to_file
    return true if self.data.nil? || !APP_CONFIG["filesystem_storage"]
    ensure_dir(FOTO_DIR)
    ensure_dir(File.join(FOTO_DIR, self.id.to_s))
    # skip storing original locally, when aws_storage is enabled
    # but we need to ensure_dir with self.id, for storing thumbnails
    return true if AWS_STORAGE

    Rails.logger.info "Saving file: #{self.path}"
    FileUtils.cp(self.data, self.path)
    true
  end

  def save_data_to_aws
    if AWS_STORAGE
      return true if self.data.nil?
      Rails.logger.info "Saving file in AWS S3: #{self.aws_path(:large)}"
      aws_dir = AWS_STORAGE_CONNECTIVITY.directories.get(AWS_BUCKET)
      #aws_dir.files.create(:key => aws_path, :body => @file_obj, :public => true, :content_type => @file_obj.content_type)

      # ensure thumbnails are generate before this step
      THUMBNAILS.keys.each do |style|
        fp = File.open(self.path(style))
        aws_dir.files.create(:key => aws_path(style), :body => fp, :public => true, :content_type => @file_obj.content_type)
      end
      # cleanup the assets on local storage
      if APP_CONFIG["filesystem_storage"]
        delete_file 
        
        # store only the original file
        ensure_dir(FOTO_DIR)
        ensure_dir(File.join(FOTO_DIR, self.id.to_s))
        FileUtils.cp(self.data, self.path)
      end
    end
    true
  end

  def delete_file
    Rails.logger.info "Deleting thumbnails.."
    remove_dir(File.join(FOTO_DIR, self.id.to_s))
    true
  end

  def ensure_dir(dirname = nil)
    raise "directory path cannot be empty" if dirname.nil?
    unless File.exist?(dirname)
      FileUtils.mkdir(dirname)
    end
  end

  def remove_dir(dirname = nil)
    raise "directory path cannot be empty" if dirname.nil?
    if File.exist?(dirname)
      FileUtils.remove_dir(dirname, true)
    end
  end

  def get_geometry(file = nil)
    `identify -format %wx%h #{file.nil? ? self.path : file.path}`.strip
  end

  def crop_file
    return true unless crop?
    `convert #{self.path} -crop '#{crop_w.to_i}x#{crop_h.to_i}+#{crop_x.to_i}+#{crop_y.to_i}' #{self.path}`
    # update the dimension after cropping
    self.data_dimension = get_geometry
  end

  def save_thumbnail
    return true if self.data.nil? || !APP_CONFIG["filesystem_storage"]
    THUMBNAILS.each do |style, size|
      Rails.logger.info "Saving #{style.to_s}.."
      frame_w, frame_h = size.split('x')
      size = self.aspect_fit(frame_w.to_i, frame_h.to_i).join('x')
      `convert #{self.data} -resize '#{size}' -quality 85 -strip -unsharp 0.5x0.5+0.6+0.008 #{self.path(style)}`
    end
    true
  end

  def extension
    File.extname(self.data_filename).gsub(/\.+/, '')
  end

  def set_sos_approved_at
    if self.sos_approved_changed? && self.sos_approved?
      self.sos_approved_at = Time.now.utc
    end
    true
  end

  #changes for hashsable polymorphic associations
  def photos_count
    1
  end

  def photo_ids
   [self.id]
  end

  def update_user_photos_count
    user.update_attribute(:photos_count, user.photos.count) if user
  end

  def send_sos_requested_mail
    AppMailer.sos_requested_mail(id).deliver
  end
end
