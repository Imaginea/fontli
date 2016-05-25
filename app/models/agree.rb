class Agree
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions
  include Scorable
  include Notifiable

  belongs_to :user, :index => true
  belongs_to :font, :index => true, :counter_cache => true

  validates :user_id, :font_id, :presence => true
  validates :user_id, :uniqueness => { :scope => :font_id, :message => 'has already accepted!' }

  after_create :inc_font_pick_status
  after_destroy :dec_font_pick_status
  
  # consider an agree from sos_requestor as publisher pick.
  def publisher_pick?
    (self.user_id == self.font.photo.user_id) || sos_requestor_pick?
  end

  def sos_requestor_pick?
    user_id.to_s == font.photo.sos_requested_by
  end
  
  def expert_pick?
    self.user.expert
  end

  def notif_target_user_id
    FontTag.where(:font_id => self.font_id).only(:user_id).collect(&:user_id)
  end

  def scorable_target_user
    User.unscoped.where(:_id => self.font.user_id).first
    #self.font.user
  end

  def active_points
    expert_pick? ? 5 : 0
  end

  def passive_points
    (expert_pick? || publisher_pick?) ? 10 : 1
  end

  private

  # increment method
  def inc_font_pick_status
    return true unless publisher_pick? || expert_pick? # nothing to do
    fnt, sts_map = [self.font, Font::PICK_STATUS_MAP.dup]
    exp_pik, pub_pik = [ sts_map[:expert_pick], sts_map[:publisher_pick] ]
    return true if expert_pick? && fnt.pick_status == exp_pik # already a expert pick
    return true if publisher_pick? && fnt.pick_status == pub_pik # already a publisher pick
    return true if fnt.pick_status == exp_pik + pub_pik # max already
    fnt.inc(:pick_status, (expert_pick? ? exp_pik : pub_pik))
    true
  end

  # decrement method
  def dec_font_pick_status
    return true unless publisher_pick? || expert_pick? # no action req.
    fnt, sts_map = [self.font, Font::PICK_STATUS_MAP.dup]
    exp_pik, pub_pik = [ sts_map[:expert_pick], sts_map[:publisher_pick] ]
    return true if expert_pick? && fnt.reload.agrees.any?(&:expert_pick?) # some other expert has also agreed
    return true if sos_requestor_pick? && fnt.reload.agrees.any?(&:publisher_pick?) # its still a publisher pick
    fnt.inc(:pick_status, -(expert_pick? ? exp_pik : pub_pik))
    true
  end
end
