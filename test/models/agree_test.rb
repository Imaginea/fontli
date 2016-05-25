require 'test_helper'

describe Agree do
  let(:expert_user) { create(:user, expert: true) }

  let(:photo)       { create(:photo, sos_requested_by: expert_user.id) }
  let(:font)        { create(:font, photo: photo, user: expert_user) }
  let(:agree)       { create(:agree, user: expert_user, font: font) }

  let(:agree1)      { create(:agree) }

  let(:user)        { create(:user) }
  let(:font1)       { create(:font, photo: create(:photo, user: user)) }
  let(:agree2)      { create(:agree, user: user, font: font1) }

  subject { Agree }

  it { must belong_to(:user) }
  it { must have_index_for(:user_id) }
  it { must belong_to(:font) }
  it { must have_index_for(:font_id) }

  it { must validate_presence_of(:user_id) }
  it { must validate_presence_of(:font_id) }
  it { must validate_uniqueness_of(:user_id).scoped_to(:font_id).with_message('has already accepted!') }

  describe 'callback' do
    describe 'after_create' do
      let(:agree) { build(:agree) }

      it 'should not change pick status of its font if its neither a publisher pick nor an expert pick' do
        agree.save
        agree.font.pick_status.must_equal 0
      end

      it 'should set the pick status of its font as 1 if its an expert pick' do
        expert_user_agree = build(:agree, user: expert_user, font: font)
        expert_user_agree.save
        expert_user_agree.font.pick_status.must_equal 1
      end

      it 'should set the pick status of its font as 2 if its an publisher pick' do
        non_expert_user_agree = build(:agree, user: user, font: font1)
        non_expert_user_agree.save
        non_expert_user_agree.font.pick_status.must_equal 2
      end
    end

    describe 'after_destroy' do
      it 'should not change pick status of its font if its neither a publisher pick nor an expert pick' do
        font = agree1.font
        font.pick_status.must_equal 0
        agree1.destroy
        font.pick_status.must_equal 0
      end

      it 'should set the pick status of its font as 1 if its an expert pick' do
        font = agree.font
        font.pick_status.must_equal 1
        agree.destroy
        font.reload.pick_status.must_equal 0
      end

      it 'should set the pick status of its font as 2 if its an publisher pick' do
        font = agree2.font
        font.pick_status.must_equal 2
        agree2.destroy
        font.reload.pick_status.must_equal 0
      end
    end
  end

  describe '#publisher_pick?' do
    it 'should return true' do
      agree.publisher_pick?.must_equal true
    end

    it 'should return true' do
      agree2.publisher_pick?.must_equal true
    end

    it 'should return false' do
      agree1.publisher_pick?.must_equal false
    end
  end

  describe '#sos_requestor_pick?' do
    it 'should return true' do
      agree.sos_requestor_pick?.must_equal true
    end

    it 'should return false' do
      agree1.sos_requestor_pick?.must_equal false
    end
  end

  describe '#expert_pick?' do
    it 'should return true' do
      agree.expert_pick?.must_equal true
    end

    it 'should return false' do
      agree1.expert_pick?.must_equal false
    end
  end

  describe '#notif_target_user_id' do
    let(:font_user) { create(:user) }

    before do
      create(:font_tag, font: agree.font, user: font_user)
    end

    it 'should return user_ids of font_tags of its font' do
      agree.notif_target_user_id.must_include font_user.id
    end

    it 'should return empty array if its font does not have any font_tags' do
      agree2.notif_target_user_id.must_be_empty
    end
  end

  describe '#scorable_target_user' do
    it 'should return its font user' do
      agree.scorable_target_user.must_equal expert_user
    end
  end

  describe '#active_points' do
    it { agree.active_points.must_equal 5 }
    it { agree1.active_points.must_equal 0 }
  end

  describe '#passive_points' do
    it { agree.passive_points.must_equal 10 }
    it { agree2.passive_points.must_equal 10 }
    it { agree1.passive_points.must_equal 1 }
  end
end
