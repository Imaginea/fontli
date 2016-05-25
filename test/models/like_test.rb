require 'test_helper'

describe Like do
  let(:like) { create(:like) }

  subject { Like }

  it { must belong_to(:user) }
  it { must belong_to(:photo) }

  it { must have_index_for(:user_id) }
  it { must have_index_for(:photo_id) }

  it { must validate_uniqueness_of(:user_id).scoped_to(:photo_id).with_message('has already liked!') }

  describe '#notif_extid' do
    it 'should return its photo_id' do
      like.notif_extid.must_equal like.photo_id.to_s
    end
  end

  describe '#notif_context' do
    it 'should return its context' do
      like.notif_context.must_equal ['has liked']
    end
  end

  describe 'scope' do
    before do
      like
    end

    it 'should return likes by active users' do
      Like.all.must_include like
    end

    it 'should not return likes by inactive users' do
      like.user.update_attribute(:active, false)
      Like.all.wont_include like
    end
  end
end
