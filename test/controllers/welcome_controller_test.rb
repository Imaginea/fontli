require 'test_helper'

describe WelcomeController do
  let(:user) { create(:user) }

  before do
    @controller.session[:user_id] = nil
  end

  describe '#index' do
    before do
      create(:storify_story)
    end

    it 'should redirect to feeds page' do
      @controller.session[:user_id] = user.id
      get :index
      assert_redirected_to '/feeds'
    end

    it 'should render template index' do
      get :index
      assert_template :index
    end
  end

  describe '#keepalive' do
    it 'should return success' do
      get :keepalive
      response.body.must_equal 'Success'
    end
  end

  describe '#api_doc' do
    it 'should return api documentation' do
      get :api_doc
      assert_template :api_doc
    end
  end

  describe '#login' do
    it 'should render login template' do
      get :login, platform: 'default'
      assert_template :login
    end

    it 'should logged in a user' do
      post :login, platform: 'default', username: user.username, password: user.password
      assert_redirected_to '/feeds'
      session[:user_id].must_equal user.id
    end

    it 'should return error message if username is not provided' do
      post :login, platform: 'default', password: user.password
      request.flash[:alert].must_equal 'Username or Password is blank!'
    end

    it 'should return error message if password is not provided' do
      post :login, platform: 'default', username: user.username
      request.flash[:alert].must_equal 'Username or Password is blank!'
    end

    it 'should return error message if wrong password is provided' do
      post :login, platform: 'default', username: user.username, password: Faker::Internet.password(6)
      request.flash[:alert].must_equal 'Invalid username or password!'
    end

    it 'should return error message if user does not exists' do
      post :login, platform: 'default', username: Faker::Name.name, password: user.password
      request.flash[:alert].must_equal 'Invalid username or password!'
    end
  end
end
