class FontTag
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions
  include Scorable
  include Notifiable

  field :coords_x, :type => Float
  field :coords_y, :type => Float

  belongs_to :user, :index => true
  belongs_to :font, :index => true

  validates :font_id, :coords_x, :coords_y, :presence => true

  after_create :update_tagged_status

  # val = 'x,y'
  def coords=(val)
    val = val.to_s.split(',')
    self.coords_x = val.first
    self.coords_y = val.last
  end

  def coords
    [self.coords_x, self.coords_y].join(',')
  end

  def scorable_target_user
    self.font.photo.user
  end

  def notif_extid
    self.font_id.to_s
  end

  def notif_target_user_id
    self.font.photo.user_id
  end

  def expert_tag?
    self.user.expert
  end

private

  def update_tagged_status
    return true unless expert_tag? # nothing to do
    fnt = self.font
    return true if fnt.expert_tagged # already expert tagged
    fnt.update_attribute(:expert_tagged, true)
    true # assume success
  end

end
