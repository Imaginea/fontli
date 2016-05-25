require 'test_helper'

describe Invite do
  let(:user)   { create(:user) }
  let(:invite) { create(:invite, user: user) }

  subject { Invite }

  it { must have_fields(:email, :extuid, :full_name).of_type(String) }
  it { must have_fields(:platform).of_type(String).with_default_value('default') }

  it { must belong_to(:user) }
  it { must have_index_for(:user_id) }
  it { must have_index_for(:email) }
  it { must have_index_for(:extuid, :platform) }

  describe 'validations' do
    it { must validate_format_of(:email).to_allow('user@test.com') }
    it { must validate_format_of(:email).to_allow('user@test.com') }
    it { wont validate_format_of(:email).to_allow('user_test_com') }

    it { must validate_presence_of(:platform) }
    it { validate_inclusion_of(:platform).to_allow(Invite::PLATFORMS) }

    it 'should validate presence of extuid and email' do
      invite = build(:invite, extuid: nil)
      invite.save
      invite.errors.must_be_empty

      invite = build(:invite, extuid: nil, email: nil)
      invite.save
      invite.errors.wont_be_empty
      invite.error_resp.must_equal 'null:: Either extuid or email is required.'
    end
  end

  describe '#mark_as_friend' do
    let(:new_user) { create(:user) }

    it 'should destroy destroy the invite and add followers' do
      invite.mark_as_friend(new_user)
      new_user.followers.must_include user
      user.followers.must_include new_user
      Invite.count.must_equal 0
    end
  end

  describe '#invite_state' do
    it 'should return its state' do
      invite.invite_state.must_equal 'Invited'
    end
  end
end
