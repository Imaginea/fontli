class HashTag
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions

  field :name, :type => String
  belongs_to :hashable, :polymorphic => true, :index => true

  validates :name, :hashable_id, :hashable_type, :presence => true

  SOS_REQUEST_HASH_TAG = 'needtypehelp'
  after_create :check_for_sos_request

  class << self
    # matches all hash_tags that starts with 'name' and
    # returns an array #OpenStruct with 'name' and 'photos_count'
    def search(name)
      return [] if name.blank?
      hsh_tags = self.where(:name => /^#{name}.*/i).to_a
      resp = hsh_tags.group_by { |ht| ht.name.downcase } # case insensitive grouping
      resp.collect do |tag_name, hsh_tags|
        fotos_cnt = self.photo_ids(hsh_tags).length
        OpenStruct.new(:name => tag_name, :photos_count => fotos_cnt)
      end
    end

    def fetch_photos(name, pge = 1, lmt = 20)
      foto_ids = HashTag.where(name: /^#{name}$/i).only(:hashable_id, :hashable_type, :name).select{|h| h.name == name }.collect(&:hashable_id)
      offst = (pge.to_i - 1) * lmt
      Photo.where(:_id.in => foto_ids).skip(offst).limit(lmt)
    end

    def photo_ids(hsh_tags)
      hsh_tags.collect{ |ht| ht.photo_ids}.flatten.uniq
    end
  end

  def photo_ids
    self.hashable.photo_ids
  end

  # BC patch after removing belongs_to :photo
  def photo
    self.hashable.is_a?(Photo) ? self.hashable : nil
  end

private

  def check_for_sos_request
    return true unless self.name.downcase == SOS_REQUEST_HASH_TAG
    return true unless self.photo # might be a workbook
    self.hashable.update_attributes(
      :font_help        => true,
      :sos_requested_by => current_user.id.to_s,
      :sos_requested_at => current_time
    )
    true
  end
end
