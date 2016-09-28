class PopularCollection < Collection
  after_save :clear_popular_photos_cache

  # memoized version of photos to be used in collection_detail api
  def fotos
    @fotos ||= Photo.popular
  end

  def photos_count
    self.fotos.count
  end

  def cover_photo_url
    # a static image, for now
    'http://s3.amazonaws.com/new_fontli_production/5288262110daa565c900000d_large.jpg'
    # url of the first popular photo
    #self.fotos.first.try(:url_large)
  end

  # cant follow dynamic collections
  def can_follow?
    false
  end

  def clear_popular_photos_cache
    Rails.cache.delete 'popular_photos' if photo_ids_changed?
  end
end
