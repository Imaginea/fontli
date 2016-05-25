class Workbook
  include Mongoid::Document
  include MongoExtensions
  include Mongoid::Timestamps

  field :title, :type => String
  field :description, :type => String
  field :photos_count, :type => Integer, :default => 0
  field :cover_photo_id, :type => Integer

  has_many :photos, :order => 'position asc', :dependent => :destroy
  has_many :hash_tags, :as => :hashable, :autosave => true, :dependent => :destroy
  belongs_to :user
  has_many :fav_workbooks, :dependent => :destroy

  validates :title, 
    :presence   => true, 
    :uniqueness => { :scope => :user_id }, 
    :length     => { :maximum => 500, :allow_blank => true }
  validates :description, :length => { :maximum => 500, :allow_blank => true }

  attr_accessor :foto_ids, :removed_foto_ids, :hashes, :ordered_foto_ids
  after_save :associate_new_photos, :unlink_removed_photos, :populate_hash_tags

  scope :recent, lambda { |cnt| desc(:created_at).limit(cnt) }
  
  class << self
    def [](wbid)
      self.where(:_id => wbid).first
    end
  end

  def photo_ids
    self.photos.only(:_id).collect(&:_id)
  end
  
private

  def associate_new_photos
    return true if self.foto_ids.blank? and self.ordered_foto_ids.blank?
    unless self.ordered_foto_ids.empty? #Making one update call if there is no order changes
      Photo.where(:_id.in => self.foto_ids).update_all(:workbook_id => self.id)
    else
      self.ordered_foto_ids.each do |foto_id,position|
        foto = Photo.where(:_id => foto_id).first
        foto.update_attributes({:workbook_id => self.id, :position => position})
      end
    end
  end

  def unlink_removed_photos
     return true if self.removed_foto_ids.blank?
     Photo.where(:_id.in => self.removed_foto_ids).update_all(:workbook_id => nil,:position => nil)
  end

  def populate_hash_tags
    return true if self.hashes.blank?
    self.hashes.each { |h| self.hash_tags.create(h) }
  end
end
