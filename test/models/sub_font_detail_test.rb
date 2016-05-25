require 'test_helper'

describe SubFontDetail do
  let(:sub_font_detail) { create(:sub_font_detail) }

  subject { SubFontDetail }

  it { must have_fields(:style_id).of_type(Integer) }
  it { must have_fields(:name, :url).of_type(String) }

  it { must embedded_in(:font_detail) }

  it { must validate_presence_of(:style_id) }
  it { must validate_presence_of(:name) }
  it { must validate_presence_of(:url) }

  describe 'callback' do
    let(:family_id)       { SecureRandom.hex(6) }
    let(:sub_font_detail) { build(:sub_font_detail) }
    let(:font)            { create(:font, subfont_id: sub_font_detail.style_id.to_s, family_id: family_id) }

    describe 'after_save' do
      before do
        font
      end

      it 'should update family_id if a font exists with same style_id but different family_id' do
        font.family_id.must_equal family_id
        sub_font_detail.save
        font.reload.family_id.wont_equal family_id
        font.family_id.must_equal sub_font_detail.font_detail.family_id.to_s
      end
    end
  end

  describe '#image' do
    it 'should generate the its cdn url' do
      sub_font_detail.image.must_equal "http://apicdn.myfonts.net/v1/fontsample?fg=666666&format=png&size=60&text=fargopudmixy&id=#{sub_font_detail.style_id}"
    end
  end

  describe '#to_obj' do
    it 'should return its font detail' do
      sub_font_detail.to_obj.wont_be_nil
    end
  end
end
