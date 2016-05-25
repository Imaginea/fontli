require 'test_helper'

describe FontTag do
  let(:user)        { create(:user) }
  let(:expert_user) { create(:user, expert: true) }
  let(:photo)       { create(:photo, user: expert_user) }
  let(:font)        { create(:font, photo: photo) }
  let(:font_tag)    { create(:font_tag, user: user, font: font) }

  subject { FontTag }

  it { must have_fields(:coords_x, :coords_y).of_type(Float) }
  it { must belong_to(:user) }
  it { must belong_to(:font) }

  it { must have_index_for(:user_id) }
  it { must have_index_for(:font_id) }

  it { must validate_presence_of(:font_id) }
  it { must validate_presence_of(:coords_x) }
  it { must validate_presence_of(:coords_y) }

  describe 'callback' do
    describe 'after_create' do
      it 'should update font expert_tagged if it is an expert_tag?' do
        tag = build(:font_tag, user: expert_user)
        tag.font.expert_tagged.must_equal false
        tag.save
        tag.font.expert_tagged.must_equal true
      end

      it 'should not update font expert_tagged if it is not an expert_tag?' do
        tag = build(:font_tag, user: user)
        tag.font.expert_tagged.must_equal false
        tag.save
        tag.font.expert_tagged.must_equal false
      end
    end

    describe 'after_destroy' do
      it 'should update font expert_tagged if it is an expert_tag?' do
        tag = create(:font_tag, user: expert_user, font: font)
        font.expert_tagged.must_equal true
        tag.destroy
        font.expert_tagged.must_equal false
      end

      it 'should not update font expert_tagged if it is not an expert_tag?' do
        tag = create(:font_tag, user: user, font: font)
        font.expert_tagged.must_equal false
        tag.destroy
        font.expert_tagged.must_equal false
      end
    end
  end

  describe '#coords=' do
    let(:coords_x) { Faker::Number.decimal(2) }
    let(:coords_y) { Faker::Number.decimal(2) }

    it 'should set font coordinates' do
      font_tag.coords = "#{coords_x}, #{coords_y}"
      font_tag.coords_x = coords_x
      font_tag.coords_y = coords_y
    end
  end

  describe '#coords' do
    it 'should return font coordinates' do
      font_tag.coords.must_equal "#{font_tag.coords_x},#{font_tag.coords_y}"
    end
  end

  describe '#scorable_target_user' do
    it 'should return user of photo of its font' do
      font_tag.scorable_target_user.must_equal expert_user
    end
  end

  describe '#notif_extid' do
    it 'should return its font id' do
      font_tag.notif_extid.must_equal font.id.to_s
    end
  end

  describe '#notif_target_user_id' do
    it 'should return user_id of photo of its font' do
      font_tag.notif_target_user_id.must_equal expert_user.id
    end
  end

  describe '#expert_tag?' do
    let(:expert_tag) { create(:font_tag, user: expert_user) }

    it 'should return true' do
      expert_tag.expert_tag?.must_equal true
    end

    it 'should return false' do
      font_tag.expert_tag?.must_equal false
    end
  end
end
