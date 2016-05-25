require 'test_helper'

describe Workbook do
  let(:workbook) { create(:workbook) }
  let(:photo)    { create(:photo, workbook: workbook) }

  subject { Workbook }

  it { must have_fields(:title, :description).of_type(String) }
  it { must have_fields(:photos_count).of_type(Integer).with_default_value(0) }
  it { must have_fields(:cover_photo_id).of_type(Integer) }

  it { must have_many(:photos) }
  it { must have_many(:hash_tags) }
  it { must have_many(:fav_workbooks) }

  it { must belong_to(:user) }

  it { must validate_presence_of(:title) }
  it { must validate_uniqueness_of(:title).scoped_to(:user_id) }
  it { must validate_length_of(:title).with_maximum(500) }

  it { must validate_length_of(:description).with_maximum(500) }

  describe 'callback' do
    let(:hashes)    { [{ name: Faker::Name.name, hashable: photo }] }
    let(:new_photo) { create(:photo) }
    let(:workbook)  { build(:workbook) }

    describe 'after_save' do
      it 'should associate new photos to workbook' do
        workbook.ordered_foto_ids = [new_photo.id]
        workbook.foto_ids = [new_photo.id]
        workbook.save
        workbook.reload.photos.must_include photo.reload
      end

      # To be fixed once the code is updated
      it 'should not associate new photos to workbook' do
        workbook.foto_ids = [new_photo.id]
        workbook.ordered_foto_ids = []
        workbook.save
        workbook.reload.photos.count.must_equal 0
      end

      it 'should unlink photos from workbook' do
        photo = create(:photo, workbook: workbook)
        workbook.photos.must_include photo
        workbook.removed_foto_ids = [photo.id]
        workbook.save
        workbook.reload.photos.wont_include photo.reload
      end

      it 'should populate hash_tags' do
        workbook.hashes = hashes
        workbook.hash_tags.count.must_equal 0
        workbook.save
        workbook.hash_tags.count.must_equal 1
      end
    end
  end

  describe '.[]' do
    it 'should return a workbook with the provided id' do
      Workbook[workbook.id].must_equal workbook
    end
  end

  describe '#photo_ids' do
    before do
      photo
    end

    it 'should return array of its photo ids' do
      workbook.photo_ids.must_include photo.id
    end
  end
end
