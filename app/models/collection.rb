class Collection
  include Mongoid::Document
  include MongoExtensions
  include Mongoid::Timestamps

  field :name, :type => String
  field :description, :type => String
  field :active, :type => Boolean, :default => false
  field :cover_photo_id, :type => String

  belongs_to :user
  has_and_belongs_to_many :photos, :dependent => :destroy

  validates :name,
    :presence   => true,
    :uniqueness => true,
    :length     => { :maximum => 100, :allow_blank => true }
  validates :description,
    :length     => { :maximum => 500, :allow_blank => true }

  scope :active, where(:active => true)

  after_create :auto_follow
  after_create :send_notification, unless: :active

  class << self
    def [](id)
      self.where(:_id => id).first
    end

    def search(name)
      name = Regexp.escape(name.strip)
      self.active.where(:name => /^#{name}.*/i).to_a
    end
  end

  # memoized version of photos to be used in collection_detail api
  def fotos
    @fotos ||= self.photos.desc(:created_at).to_a
  end

  def photos_count
    self.photos.count
  end

  def cover_photo_url
    Photo.where(:_id => self.cover_photo_id).first.try(:url_large)
  end

  # TODO: yet to test
  def followed_users
    @followed_users ||= follow_scope.to_a
  end

  def follows_count
    @follows_count ||= follow_scope.count
  end

  # is current user following this collection
  def can_follow?
    current_user.can_follow_collection?(self)
  end

  # custom collections are created by our users
  # while the system collections are created by admin (no user_id)
  def custom?
    self.user_id.present?
  end

  private

  def follow_scope
    User.following_collection(self.id)
  end

  def auto_follow
    self.user.follow_collection(self) if custom?
  end

  def send_notification
    AppMailer.inactive_collection_creation_mail(id).deliver
  end
end
