require 'test_helper'

describe PopularCollection do
  let(:photo)              { create(:photo) }
  let(:popular_collection) { create(:popular_collection) }

  describe '#fotos' do
    before do
      create(:like, photo: photo)
      photo.reload
    end

    it 'should return popular photos' do
      popular_collection.fotos.must_include photo
    end
  end

  describe '#photos_count' do
    before do
      create(:like, photo: photo)
      photo.reload
    end

    it 'should return popular photos count' do
      popular_collection.photos_count.must_equal 1
    end
  end

  describe '#cover_photo_url' do
    it 'should return cover photo url' do
      popular_collection.cover_photo_url.must_equal 'http://s3.amazonaws.com/new_fontli_production/5288262110daa565c900000d_large.jpg'
    end
  end

  describe '#can_follow?' do
    it 'should return false' do
      popular_collection.can_follow?.must_equal false
    end
  end
end
