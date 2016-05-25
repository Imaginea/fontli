require 'test_helper'

describe HashTag do
  let(:photo)    { create(:photo) }
  let(:hash_tag) { create(:hash_tag, hashable: photo) }

  subject { HashTag }

  it { must have_fields(:name).of_type(String) }

  it { must belong_to(:hashable) }

  it { must have_index_for(:hashable_id, :hashable_type) }

  it { must validate_presence_of(:name) }
  it { must validate_presence_of(:hashable_id) }
  it { must validate_presence_of(:hashable_type) }

  describe 'callback' do
    let(:new_hash_tag) { build(:hash_tag, name: HashTag::SOS_REQUEST_HASH_TAG, hashable: photo) }

    describe 'after_create' do
      it 'should check for sos and mark the sos for font help' do
        photo.font_help.must_equal false
        new_hash_tag.save
        photo.font_help.must_equal true
      end
    end
  end

  describe '.search' do
    it 'should not be empty if hash_tag with the provided name is found' do
      HashTag.search(hash_tag.name).wont_be_empty
    end

    it 'should be empty' do
      HashTag.search(Faker::Name.name).must_be_empty
    end
  end

  describe '.photo_ids' do
    before do
      hash_tag
    end

    it 'should return its photo_ids' do
      HashTag.photo_ids(HashTag.all).must_include photo.id
    end
  end

  describe '#photo_ids' do
    it 'should return its photo_ids' do
      hash_tag.photo_ids.must_include photo.id
    end
  end

  describe '#photo' do
    let(:hash_tag1) { create(:hash_tag, hashable: create(:font)) }

    it 'should return nil' do
      hash_tag1.photo.must_equal nil
    end

    it 'should return photo' do
      hash_tag.photo.must_equal photo
    end
  end
end
