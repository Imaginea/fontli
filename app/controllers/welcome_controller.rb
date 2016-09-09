require 'auth_client'
require 'storify_client'

class WelcomeController < ApplicationController
  include AuthClient
  skip_before_filter :login_required
  skip_before_filter :set_current_controller, :only => [:keepalive]

  layout :select_layout

  def keepalive
    render :text => 'Success'
  end

  def index
    redirect_to(feeds_url) && return if logged_in?
    @story   = StorifyStory.random_story
    @popular = Photo.for_homepage.only(:id,:data_filename).to_a
    @homepage, @meta_title = true, 'Home'
  end

  def login
    return if request.get?
    self.send format('%s_login', params[:platform])
  end

  #def auth_callback
  #  self.send format('%s_callback', params[:platform])
  #end

  def api_doc
    render 'api_doc', :layout => false
  end

  private

  #def facebook_login
  #  if fb_authorized?
  #    usr_obj = FbGraph::User.me(fb_client.access_token)
  #    check_and_handle_fb_user(usr_obj)
  #  else
  #    auth_url = fb_authorize
  #    redirect_to auth_url
  #  end
  #end

  #def twitter_login
  #  if twt_authorized?
  #    usr_hsh = twt_client.info
  #    check_and_handle_twt_user(usr_hsh)
  #  else
  #    resp = twt_get_token
  #    session[:twt_request_token] = resp.token
  #    session[:twt_request_token_secret] = resp.secret
  #    redirect_to resp.authorize_url
  #  end
  #end

  def default_login
    uname, pass = [params[:username], params[:password]]
    if uname.blank? || pass.blank?
      flash.now[:alert] = 'Username or Password is blank!'
      return false
    end
    u = User.login uname, pass
    unless u.nil?
      session[:user_id] = u.id
      redirect_to feeds_url
    else
      flash.now[:alert] = 'Invalid username or password!'
    end
  end

  #def twitter_callback
  #  if params[:denied]
  #    redirect_to login_url(:default), :alert => 'Unauthorized!'
  #    return
  #  end

    # Exchange the request token for an access token.
  #  resp = twt_authorize params[:oauth_verifier]

  #  if twt_authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  We can also consider persisting these details in DB.
  #    session[:twt_access_token] = resp.token
  #    session[:twt_secret_token] = resp.secret
  #    usr_hsh = JSON.parse resp.response.body
  #    check_and_handle_twt_user(usr_hsh)
  #  else
  #    redirect_to login_url(:default), :alert => 'Twitter Auth failed!'
  #  end
  #end

  #def facebook_callback
  #  if params[:error] == "access_denied"
  #    redirect_to login_url(:default), :alert => 'Unauthorized!'
  #    return
  #  end

  #  token = fb_get_token(params[:code])

  #  if token
  #    session[:fb_access_token] = token
  #    usr_obj = FbGraph::User.me(token).fetch
  #    check_and_handle_fb_user(usr_obj)
  #  else
  #    redirect_to login_url(:default), :alert => 'Facebook Auth failed!'
  #  end
  #end

  #def check_and_handle_twt_user(usr_hsh)
  #  usr = User.by_extid(usr_hsh['id_str'])
  #  if usr.nil? # new user
  #    @user = User.new(
  #      :username => usr_hsh['screen_name'],
  #      :email => usr_hsh['email'],
  #      :full_name => usr_hsh['name'],
  #      :extuid => usr_hsh['id_str'],
  #      :description => usr_hsh['description'],
  #      :website => usr_hsh['url']
  #    )
  #    @avatar_url = usr_hsh['profile_image_url']
  #    render :signup, :layout => 'old'
  #  else
  #    session[:user_id] = usr.id
  #    redirect_to feeds_url
  #  end
  #end

  #def check_and_handle_fb_user(usr_obj)
  #  usr = User.by_extid(usr_obj.identifier)
  #  if usr.nil? # new user
  #    @user = User.new(
  #      :username => (usr_obj.first_name.downcase+' ' + usr_obj.identifier).gsub(' ', '.').first(15),
  #      :email => usr_obj.email,
  #      :full_name => usr_obj.name,
  #      :extuid => usr_obj.identifier,
  #      :description => usr_obj.bio,
  #      :website => usr_obj.link
  #    )
  #    @avatar_url = usr_obj.picture
  #    render :signup, :layout => 'old'
  #  else
  #    session[:user_id] = usr.id
  #    redirect_to feeds_url
  #  end
  #end

  def select_layout
    case params[:action].to_sym
    when :login
      'plain'
    else
      'application'
    end
  end
end
