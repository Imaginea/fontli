require 'test_helper'

describe Mention do
  let(:photo)   { create(:photo) }
  let(:mention) { create(:mention, mentionable: photo) }

  subject { Mention }

  it { must have_fields(:username).of_type(String) }

  it { must belong_to(:mentionable) }
  it { must belong_to(:user) }

  it { must have_index_for(:mentionable_id, :mentionable_type) }
  it { must have_index_for(:user_id) }

  it { must validate_presence_of(:user_id) }
  it { must validate_presence_of(:username) }
  it { must validate_presence_of(:mentionable_id) }
  it { must validate_presence_of(:mentionable_type) }

  describe '#notif_source_user_id' do
    it 'should return user_id of its mentionable' do
      mention.notif_source_user_id.must_equal photo.user_id
    end
  end

  describe '#notif_target_user_id' do
    it 'should return its user_id' do
      mention.notif_target_user_id.must_equal mention.user_id
    end
  end

  describe '#notif_context' do
    it 'should return its context' do
      mention.notif_context.must_equal ['has mentioned']
    end
  end
end
