class Follow
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions
  include Scorable
  include Notifiable

  belongs_to :user, :index => true, :inverse_of => :follows
  belongs_to :follower, :class_name => 'User', :index => true, :inverse_of => :my_followers

  validates :follower_id, :user_id, :presence => true
  validates :follower_id, :uniqueness => { :scope => :user_id, :message => 'is already a friend!' }

  def scorable_target_user
    User.unscoped.where(:_id => self.follower_id).first
    #self.follower
  end

  def notif_target_user_id
    self.follower_id
  end
end
