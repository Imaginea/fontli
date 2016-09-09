require 'test_helper'

describe FontsController do
  let(:photo) { create(:photo) }
  let(:user)  { create(:user) }
  let(:font)  { create(:font, family_name: Faker::Name.name) }

  before do
    @controller.session[:user_id] = user.id
  end

  describe '#tag_font' do
    let(:font_params) do
      {
        family_unique_id: '5352',
        family_name: 'Baskerville Classico',
        family_id: '5352',
        coords: '6.269071,5.9104867'
      }
    end

    it 'should add a comment for the provided photo' do
      assert_difference 'Comment.count', 1 do
        post :tag_font, photo_id: photo.id, font: font_params
      end
    end

    it 'should return fonts' do
      post :tag_font, photo_id: photo.id, font: font_params
      assigns(:fonts).first.family_name.must_equal font_params[:family_name]
    end
  end

  describe '#font_autocomplete' do
    before do
      FontFamily.stubs(:font_autocomplete).returns({})
    end

    it 'should return status 200' do
      get :font_autocomplete
      response.code.must_equal '200'
    end
  end

  describe '#font_details' do
    before do
      FontFamily.stubs(:font_details).returns([])
    end

    it 'should return status 200' do
      xhr :get, :font_details, fontname: font.family_name
      response.code.must_equal '200'
    end
  end

  describe '#sub_font_details' do
    before do
      FontFamily.stubs(:sub_font_details).returns([])
    end

    it 'should raise error' do
      proc { get :sub_font_details, uniqueid: font.family_unique_id }.must_raise ActionView::MissingTemplate
    end
  end
end
