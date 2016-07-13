require 'api_helper'
class ApiBaseController < ActionController::Base

  before_filter :set_current_controller
  before_filter :verify_api_params
  before_filter :load_api_params
  before_filter :load_user_and_check_sess_expiry, :except => ApiHelper::AUTHLESS_APIS
  before_filter :restrict_guest_users, :except => ApiHelper::GUEST_USER_ALLOWED_APIS

  def current_user
    @current_user ||= if @extuid_token
      User.by_extid(@extuid_token)
    else
      sess = @current_session || current_session
      return nil if sess.nil?
      sess.user
    end
  end

  protected
  def current_session
    return nil if @auth_token.nil?
    token_str = URI.unescape(@auth_token) # CGI.unescape won't work if auth_token is unescaped already
    token, devic_id = token_str.split('||')
    @current_session ||=  devic_id ? ApiSession[token, devic_id] : ApiSession.where(:auth_token => token).first
  end
  
  def reset_current_user_and_session
    @current_user = nil
    @current_session = nil
  end

  def render_response(result, status = true, error = nil)
    resp = formatted_response(result, status, error)
    respond_to do |format|
      format.json { render :json => resp.as_json }
      format.html { render :json => resp.as_json }
    end
  end

  def load_api_params
    pms = [:auth_token, :extuid_token] # default req param
    pms += current_api_signature_map[:accepts].flatten
    pms.compact.each { |p| instance_variable_set("@#{p.to_s}", params[p]) }
    @extuid_token ||= get_extuid_token
  end

  def current_api_accepts_map
    accepts = current_api_signature_map[:accepts].flatten
    accepts.inject({}) { |hsh, key| hsh.update(key => instance_variable_get("@#{key.to_s}") ) }
  end

  def current_api_accepts_map_with_user
    current_api_accepts_map.merge(:user_id => current_user.id)
  end

  # reject params that are not passed
  def current_api_valid_accepts_map
    current_api_accepts_map.reject { |k, v| v.nil? }
  end

  def current_api_signature_map
    ApiHelper::SIGNATURE_MAP[current_api]
  end

  def current_api_req_params
    pms = current_api_signature_map[:accepts].dup
    pms.pop if pms.last.is_a?(Array) # filter optional params
    pms
  end

  def populate_likes_comments_info(photos)
    foto_ids = photos.collect(&:id)

    foto_lks = Like.where(:photo_id.in => foto_ids).desc(:created_at).to_a
    foto_cmts = Comment.where(:photo_id.in => foto_ids).desc(:created_at).to_a

    usr_ids = (foto_lks.collect(&:user_id) + foto_cmts.collect(&:user_id))
    usr_ids = usr_ids.flatten.uniq
    usrs_map = [] if usr_ids.empty?
    usrs_map ||= User.where(:_id.in => usr_ids).only(:id, :username).to_a

    # generate #Hash's for faster lookup
    foto_lks = foto_lks.group_by(&:photo_id)
    foto_cmts = foto_cmts.group_by(&:photo_id)
    usrs_map = usrs_map.group_by(&:id)

    # populate 'liked_user' and 'commented_user' flags
    photos.each do |p|
      lks, cmts = [ foto_lks[p.id], foto_cmts[p.id] ]
      # get the last two usernames(seperated by ||) who liked/commented on the photo
      p.liked_user =  lks[0..1].collect { |l| usrs_map[l.user_id].first.username }.join('||') unless lks.nil?
      p.commented_user = cmts[0..1].collect { |c| usrs_map[c.user_id].first.username }.join('||') unless cmts.nil?
    end
  end

private
  
  # extuid_token is derived from auth_token, when it doesn't include "||"
  # uses encryptor plugin. Check initializers for decryption options used.
  def get_extuid_token
    return nil if @auth_token.nil? || URI.unescape(@auth_token).include?("||")
    token = URI.unescape(@auth_token)
    @auth_token = nil # force this to nil
    Encryptor.decrypt(token)
  end

  def set_current_controller
    Thread.current[:current_controller] = self
    @current_user = nil # make sure to reset current_user for every request
  end

  def current_api
    params[:action].to_sym
  end

  def verify_api_params
    param_keys = params.keys.collect(&:to_sym)
    missing_params = current_api_req_params - param_keys
    if missing_params.any?
      msg = "Required params missing - #{missing_params.join(", ")}"
      render_response(nil, false, msg)
    end
  end

  def load_user_and_check_sess_expiry
    render_response(nil, false, :token_not_found) && return unless current_user
    render_response(nil, false, :token_expired) unless current_session.nil? || current_session.active?
  end

  def restrict_guest_users
    return true unless current_user
    render_response(nil, false, :guest_not_allowed) if current_user.guest?
  end

  def formatted_response(result, status = true, error = nil)
    resp = { :response => formatted_result(result), :status => formatted_status(status) }
    resp.update(:errors => formatted_error(error)) unless status
    add_common_attrs_to_resp(resp)
  end

  def formatted_result(result = nil)
    return "" if result.nil?
    returns = current_api_signature_map[:returns]
    returns.is_a?(Array) ? current_api_result_map(result, returns) : result
  end

  # generates the response array, recursively - if one of response attr is a collection by itself.
  def current_api_result_map(result, returns)
    result_types = [Array, Mongoid::Relations::Targets::Enumerable]
    return result.collect { |res| current_api_result_map(res, returns) } if result_types.include?(result.class)
    returns_with_conditional(result, returns).inject({}) do |hsh, meth|
      val = result.send(meth)
      val = current_api_result_map(val, current_api_signature_map[meth] ) if result_types.include?(val.class)
      hsh.update(meth => (val.nil? ? '' : val)) # send '' instead of nil
    end
  end

  # to add attrs like my_notifications_count in api response, based on basic conditions
  # For now, all attr are called on current_user. This might change in future
  def add_common_attrs_to_resp(resp_map)
    return resp_map if current_user.nil?
    ApiHelper::COMMON_RESPONSE_ATTRS.each do |attr|
      next if current_api == attr # avoid duplicates
      resp_map.update(attr => @current_user.send(attr))
    end
    resp_map
  end

  # some apis(ex.,my_notifications) include attrs on response dynamically and conditionally.
  def returns_with_conditional(result, returns)
    cond_ret_opts = current_api_signature_map[:conditionally_return]
    return returns if cond_ret_opts.nil?
    cond_meth = cond_ret_opts[:if]
    returns += cond_ret_opts[:attrs] if result.send(cond_meth)
    returns
  end

  def formatted_status(status)
    status ? "Success" : "Failure"
  end

  def formatted_error(error)
    case error.class.to_s
    when 'Symbol'
      ApiHelper::ERROR_MESSAGE_MAP[error]
    when 'Array' # AR errors
      error.join('||')
    else # custom string/empty
      error.to_s
    end
  end

end
