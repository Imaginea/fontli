require 'test_helper'

describe Font do
  let(:user)       { create(:user) }
  let(:photo)      { create(:photo) }
  let(:font)       { create(:font, photo: photo) }
  let(:other_font) { create(:font, created_at: 2.months.ago) }
  let(:font1)      { create(:font, family_name: Faker::Name.name) }
  let(:font2)      { create(:font, subfont_name: Faker::Name.name, subfont_id: SecureRandom.hex) }
  let(:font_tag)   { create(:font_tag, font: font) }

  subject { Font }

  it { must have_fields(:family_unique_id, :family_id, :family_name, :subfont_name, :subfont_id).of_type(String) }
  it { must have_fields(:agrees_count, :font_tags_count, :pick_status).of_type(Integer).with_default_value(0) }
  it { must have_fields(:expert_tagged).of_type(Boolean).with_default_value(false) }

  it { must belong_to(:photo) }
  it { must belong_to(:user) }

  it { must have_index_for(:photo_id) }
  it { must have_index_for(:user_id) }

  it { must have_many(:agrees) }
  it { must have_many(:font_tags) }
  it { must have_many(:fav_fonts) }
  it { must have_many(:hash_tags) }

  it { must validate_presence_of(:family_unique_id) }
  it { must validate_presence_of(:family_id) }
  it { must validate_presence_of(:photo_id) }
  it { must validate_presence_of(:user_id) }

  describe '.[]' do
    it 'should return a font with the provided id' do
      Font[font.id].must_equal font
    end

    it 'should not return a font which does not have the provided id' do
      Font[other_font.id].wont_equal font
    end
  end

  describe '.add_agree_for' do
    it 'should return font not found' do
      Font.add_agree_for(SecureRandom.hex, font.user_id).must_equal [nil, :font_not_found]
    end

    it 'should create an agree' do
      font.agrees.count.must_equal 0
      Font.add_agree_for(font.id, font.user_id).must_equal true
      font.agrees.count.must_equal 1
    end
  end

  describe '.unagree_for' do
    before do
      create(:agree, font: font, user: user)
    end

    it 'should return font not found' do
      Font.unagree_for(SecureRandom.hex, font.user_id).must_equal [nil, :font_not_found]
    end

    it 'should return record not found' do
      Font.unagree_for(font.id, SecureRandom.hex).must_equal [nil, :record_not_found]
    end

    it 'should destroy an agree' do
      font.agrees.count.must_equal 1
      Font.unagree_for(font.id, user.id).must_equal true
      font.agrees.count.must_equal 0
    end
  end

  describe '.tagged_photos_for' do
    it 'should return an empty array' do
      Font.tagged_photos_for(family_id: SecureRandom.hex).must_be_empty
    end

    it 'should return the tagged photos of the font' do
      Font.tagged_photos_for(family_id: font.family_id).must_include photo
    end
  end

  describe '.tagged_photos_popular' do
    before do
      create_list(:agree, 3, font: font)
      font.reload
    end

    it 'should return an empty array' do
      Font.tagged_photos_popular(family_id: SecureRandom.hex).must_be_empty
    end

    it 'should return the popular tagged photos of the font' do
      Font.tagged_photos_popular(font.family_id).must_include photo
    end
  end

  describe '.popular' do
    before do
      font
      other_font
    end

    it 'should return fonts created within 1 month' do
      Font.popular.must_include font
    end

    it 'should not return fonts created before 1 month' do
      Font.popular.wont_include other_font
    end
  end

  describe '.random_popular_photo' do
    let(:popular_photo) { create(:photo, show_in_header: true) }
    let(:popular_font)  { create(:font, photo: popular_photo) }

    before do
      create_list(:agree, 3, font: popular_font)
      create_list(:agree, 3, font: font)

      popular_font.reload
      font.reload
    end

    it 'should return random popular photo' do
      Font.random_popular_photo.must_include popular_photo
    end

    it 'should not return photo which are not allowed to show in header' do
      Font.random_popular_photo.wont_include photo
    end
  end

  describe '.api_recent' do
    before do
      create_list(:agree, 3, font: font)
      font.reload
    end

    it 'should return font having 2 agrees_count' do
      Font.api_recent.must_include font
    end

    it 'should not return font which is not having 2 agrees_count' do
      Font.api_recent.wont_include other_font
    end
  end

  describe '.search' do
    it 'should return empty array if name is blank' do
      Font.search('').must_be_empty
    end

    it 'should return empty array if fonts are not found whose family_name or subfont_name is same as the provided name' do
      Font.search(Faker::Name.name).must_be_empty
    end

    it 'should return a font having family_name same as the provided name' do
      Font.search(font1.family_name).must_include font1
    end

    it 'should return a font having subfont_name same as the provided name' do
      Font.search(font2.subfont_name).must_include font2
    end
  end

  describe '.search_autocomplete' do
    it 'should return empty array if name is blank' do
      Font.search_autocomplete('').must_be_empty
    end

    it 'should return empty array if fonts are not found whose family_name or subfont_name is same as the provided name' do
      Font.search_autocomplete(Faker::Name.name).must_be_empty
    end

    it 'should return an array of font names if a font is found with family_name same as provided name' do
      Font.search_autocomplete(font1.family_name).must_equal [font1.family_name]
    end

    it 'should return an array of font names if a font is found with subfont_name same as the provided name' do
      Font.search_autocomplete(font2.subfont_name).must_equal [font2.subfont_name]
    end
  end

  describe '#tagged_photos_count' do
    it 'should return a value' do
      font.tagged_photos_count.must_equal 1
    end
  end

  describe '#favs_count' do
    before do
      create(:fav_font, font: font)
    end

    it 'should return a value' do
      font.favs_count.must_equal 1
    end
  end

  describe '#fav_users' do
    let(:fav_font) { create(:fav_font, font: font) }

    before do
      fav_font
    end

    it 'should return fav_fonts users' do
      font.fav_users(1).must_include fav_font.user
    end
  end

  describe '#hashes=' do
    it 'should build its hash_tags' do
      font.hashes = [{ name: Faker::Name.name }]
      font.hash_tags.wont_be_empty
    end
  end

  describe '#tags_count' do
    before do
      font_tag
      font.reload
    end

    it 'should return font tags count' do
      font.tags_count.must_equal 1
    end

    it 'should return o if font has no tags' do
      font1.tags_count.must_equal 0
    end
  end

  describe '#heat_map' do
    before do
      font_tag
    end

    it 'should return empty if font has no tags' do
      font1.heat_map.must_be_empty
    end

    it 'should not be empty if font has tags' do
      font.heat_map.wont_be_empty
    end
  end

  describe '#tagged_users' do
    before do
      font_tag
    end

    it 'should return tagged user' do
      font.tagged_users.must_include font_tag.user
    end
  end

  describe '#tagged_user_ids' do
    before do
      font_tag
    end

    it 'should return tagged user ids' do
      font.tagged_user_ids.must_include font_tag.user_id
    end
  end

  describe '#recent_tagged_unames' do
    before do
      font_tag
    end

    it 'should return tagged usernames' do
      font.recent_tagged_unames.must_include font_tag.user.username
    end

    it 'should be empty if font has no tags' do
      font1.recent_tagged_unames.must_be_empty
    end
  end

  describe '#key' do
    it 'should return combination of family id and subfont id' do
      font2.key.must_equal "#{font2.family_id}_#{font2.subfont_id}"
    end
  end

  describe '#display_name' do
    it 'should return subfont name as the display name' do
      font2.display_name.must_equal font2.subfont_name
    end

    it 'should return family name as the display name' do
      font1.display_name.must_equal font1.family_name
    end
  end

  describe '#photo_ids' do
    it 'should return the photo ids' do
      font.photo_ids.must_include photo.id
    end
  end

  describe '#myfonts_url' do
    let(:font_detail) { create(:font_detail, family_id: font.family_id) }

    before do
      font_detail
    end

    # Update the return value once the font_detail family_id type is fixed
    it 'should return url of its details' do
      font.myfonts_url.must_equal nil
    end
  end
end
