class FontTag
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions
  include Scorable
  include Notifiable

  field :coords_x, :type => Float
  field :coords_y, :type => Float

  belongs_to :user, :index => true
  belongs_to :font, :index => true, :counter_cache => true

  validates :font, :coords_x, :coords_y, :presence => true

  after_create :update_tagged_status
  after_destroy :reupdate_tagged_status
  after_destroy :remove_photo_comments

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
    User.unscoped.where(:_id => self.font.photo.user_id).first
    #self.font.photo.user
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

  # update the expert_tagged status, if this is the only tag by an expert.
  def reupdate_tagged_status
    exp_usr_ids = User.all_expert_ids # includes flagged users too
    exp_tagged  = font.tagged_user_ids.any? { |uid| exp_usr_ids.include? uid }
    font.update_attribute(:expert_tagged, false) unless exp_tagged
    true
  end

  def remove_photo_comments
    comment = font.photo.comments.where(font_tag_ids: id).last
    return true unless comment

    comment.font_tag_ids.delete(id)

    if comment.font_tag_ids.empty?
      comment.destroy
    else
      comment.save
    end
  end
end
