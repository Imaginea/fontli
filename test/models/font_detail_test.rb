require 'test_helper'

describe FontDetail do
  let(:font_detail)          { create(:font_detail) }
  let(:sub_font_detail_hash) do
    {
      style_id: SecureRandom.random_number(100_000),
      name:     Faker::Name.name,
      url:      Faker::Internet.url
    }
  end

  subject { FontDetail }

  it { must have_field(:family_id).of_type(Integer) }
  it { must have_field(:name, :url, :desc, :owner).of_type(String) }

  it { must have_index_for(:family_id) }
  it { must embed_many(:sub_font_details) }

  it { must validate_presence_of(:family_id) }
  it { must validate_presence_of(:name) }
  it { must validate_presence_of(:url) }
  it { must validate_presence_of(:owner) }

  describe '.ensure_create' do
    let(:details_hash) do
      {
        id:    SecureRandom.random_number(100_000),
        name:  Faker::Name.name,
        url:   Faker::Internet.url,
        desc:  Faker::Lorem.sentence,
        owner: Faker::Name.name,
        styles: [{ id:   SecureRandom.random_number(100_000),
                   name: Faker::Name.name,
                   url:  Faker::Internet.url }]
      }
    end

    it 'should create a font_detail and its subfonts' do
      FontDetail.count.must_equal 0
      SubFontDetail.count.must_equal 0

      FontDetail.ensure_create(details_hash)

      FontDetail.count.must_equal 1
      FontDetail.last.sub_font_details.count.must_equal 1
    end
  end

  describe '.for' do
    it 'should return a font_detail' do
      FontDetail.for(font_detail.family_id).must_equal font_detail
    end

    it 'should return a sub_font_detail' do
      font_detail.sub_font_details.create(sub_font_detail_hash)
      FontDetail.for(font_detail.family_id, sub_font_detail_hash[:style_id]).must_equal font_detail.sub_font_details.last.to_obj
    end
  end

  describe '#image' do
    it 'should generate the font cdn url to the samples' do
      font_detail.image.must_equal "http://apicdn.myfonts.net/v1/fontsample?fg=666666&format=png&size=60&text=fargopudmixy&id=#{font_detail.family_id}&idtype=familyid"
    end
  end

  describe '#subfont' do
    it 'should return subfont of the font_detail' do
      sub_font_detail = font_detail.sub_font_details.create(sub_font_detail_hash)
      font_detail.subfont(sub_font_detail_hash[:style_id]).must_equal sub_font_detail
    end
  end
end
