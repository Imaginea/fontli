require 'test_helper'

describe Comment do
  let(:user)     { create(:user) }
  let(:photo)    { create(:photo) }
  let(:comment)  { create(:comment, photo: photo, user: user) }
  let(:font_tag) { create(:font_tag) }

  subject { Comment }

  it { must have_fields(:body).of_type(String) }
  it { must have_fields(:font_tag_ids, :foto_ids).of_type(Array) }

  it { must belong_to(:photo) }
  it { must have_index_for(:photo_id) }
  it { must belong_to(:user) }
  it { must have_index_for(:user_id) }

  it { must have_many(:mentions) }

  it { must validate_presence_of(:user_id) }
  it { must validate_presence_of(:photo_id) }
  it { must validate_length_of(:body).with_maximum(500) }

  describe 'callback' do
    describe 'after_create' do
      it 'should populate mentions if its body contain username' do
        comment = create(:comment, body: "mention @#{user.username}")
        comment.mentions.wont_be_empty
      end
    end

    describe 'after_destroy' do
      it 'should delete font_tags' do
        comment.update_attribute(:font_tag_ids, [font_tag.id])
        FontTag.count.must_equal 1
        comment.destroy
        FontTag.count.must_equal 0
      end
    end
  end

  describe '.[]' do
    it 'should find a comment with the provided id' do
      Comment[comment.id].must_equal comment
    end
  end

  describe '#notif_target_user_id' do
    it 'should return owner of the photo' do
      comment.notif_target_user_id.must_include photo.user.id
    end

    it 'should return other users who commented on the photo' do
      comment1 = create(:comment, photo: photo)
      comment.notif_target_user_id.must_include comment1.user.id
    end
  end

  describe '#fonts' do
    it 'should return empty array if font_tag_ids is blank' do
      comment.fonts.must_be_empty
    end

    it 'should return font if font_tag_ids is present' do
      comment.update_attribute(:font_tag_ids, [font_tag.id])
      comment.fonts.wont_be_empty
    end
  end

  describe '#username' do
    it 'should return username of of its user' do
      comment.username.must_equal user.username
    end
  end

  describe '#user_url_thumb' do
    it 'should return url_thumb of of its user' do
      comment.user_url_thumb.must_equal user.url_thumb
    end
  end

  describe '#notif_context' do
    it 'should return an array' do
      comment.notif_context.must_equal ['has commented']
    end
  end

  describe '#fotos' do
    it 'should return empty array if foto_ids is blank' do
      comment.fotos.must_be_empty
    end

    it 'should return photos array' do
      comment.update_attribute(:foto_ids, [photo.id])
      comment.fotos.must_include photo
    end
  end
end
