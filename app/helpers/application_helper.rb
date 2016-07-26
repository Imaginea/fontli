module ApplicationHelper
  def meta_title
    title = 'Fontli'
    title_from_action = params[:action].titleize
    unless params[:type].blank?
      title_from_action << " #{params[:type].titleize.pluralize}"
    end
    title << ": #{@meta_title || title_from_action}"
  end

  def meta_keywords
    kw = ['typography,fontli,type love,font sharing']
    add_kw = if @user
      [@user.username, @user.full_name].compact.join(',')
    elsif @photo && !@photo.caption.blank?
      @photo.caption
    elsif @font
      @font.display_name
    end
    (kw + [add_kw].compact).join(',')
  end

  def flash_notices
    cnt = "".html_safe
    [:notice, :alert].each do |k|
      cnt << content_tag(:div, flash[k], :id => k.to_s) if flash.key?(k)
    end
    cnt
  end

  def errors_for(obj)
    errs = obj.errors.collect do |k, v|
      k = '' if k == :base # don't add Base
      msg = k.to_s.humanize + ' ' + v
      content_tag(:li, msg)
    end.join.html_safe
    content_tag(:ul, errs, :id => 'errors') unless errs.blank?
  end

  # obj param can be model obj or obj.errors.full_messages array
  def simple_errors_for(obj_or_errs)
    return "" if obj_or_errs.blank?
    errs  = obj_or_errs.errors.full_messages if obj_or_errs.respond_to?(:errors)
    outpt = (errs || obj_or_errs).join('<br/>').html_safe
    content_tag(:div, outpt, :class => 'errors') unless outpt.blank?
  end
  
  def hidden_user_detail_tags(f)
    return "" if params[:platform] == 'default'
    cnt = f.hidden_field(:platform, :value => params[:platform])
    cnt << f.hidden_field(:extuid, :value => @user.extuid)
    cnt << f.hidden_field(:avatar_url,
                          :value => @user.avatar_url || @avatar_url)
    cnt
  end

  def signup_welcome_note
    return "" if params[:platform] == 'default'
    opts = { 
      :name   => @user.full_name,
      :avatar => @user.avatar_url || @avatar_url
    }
    note = content_tag(:p, "Hi #{opts[:name]}!", :class => 'username')
    note << content_tag(:span, 'Please complete the form below to register your account.')
    wel_note = "<img src='#{opts[:avatar]}' />".html_safe
    wel_note << content_tag(:div, note, :class => 'left')
    wel_note << "<p class='clear'></p>".html_safe
    content_tag(:div, wel_note, :class => 'welcome-note')
  end

  def timestamp(dattime)
    if (Time.now - dattime) < 5.minutes
      'Just now'
    else
      str = distance_of_time_in_words_to_now(dattime)
      # truncate almost/about or any kind of prefix
      str.gsub(/^[a-zA-Z]*\s/, '') + ' ago'
    end
  end

  def profile_image(usr=nil, size=:small)
    u = usr || @user || current_user
    src = size == :small ? u.url_thumb : u.url_large
    style = size == :small ? 'width:50px;height:50px' : 'width:inherit;height:inherit'
    content_tag(:img, nil, :src => src, :style => style)
  end

  def photo_details_li(foto=nil)
    foto ||= @photo
    lks = cmts = fnts = ''
    ts = content_tag(:span, timestamp(foto.created_at))

    css_class = 'likes_cnt' + (foto.likes_count > 0 ? '' : ' hidden')
    lks = content_tag(:a, pluralize(foto.likes_count, 'like'), :href => "javascript:;", :class => css_class, :id => "likes_cnt_#{foto.id}")

    css_class = 'comments_cnt' + (foto.comments_count > 0 ? '' : ' hidden')
    cmts = content_tag(:a, pluralize(foto.comments_count, 'comment'), :href => "javascript:;", :class => css_class, :id => "comments_cnt_#{foto.id}")

    css_class = 'fonts_cnt' + (foto.fonts_count > 0 ? '' : ' hidden')
    fnts = content_tag(:a, pluralize(foto.fonts_count, 'font'), :href => "javascript:;", :class => css_class, :id => "fonts_cnt_#{foto.id}", 'data-url' => feed_fonts_path(:id => foto.id))

    ts + lks + cmts + fnts
  end

  # returns {font_tag_id1 => #font1, font_tag_id2 => #font2, .. }
  def fonts_map_for_comments(cmts)
    fnt_tag_ids = cmts.collect(&:font_tag_ids).flatten.uniq
    fnt_tags = FontTag.where(:_id.in => fnt_tag_ids).only(:id,:font_id).to_a
    fnt_ids = fnt_tags.collect(&:font_id).uniq
    fnts_by_id = Font.where(:_id.in => fnt_ids).to_a.group_by(&:id)

    fnt_tags.inject({}) do |hsh, ft|
      hsh.update(ft.id.to_s => fnts_by_id[ft.font_id].first)
    end
  end

  def login_required_class
    'login-req' if !logged_in?
  end

  def user_countdown_count
    Rails.env.production? ? User.count : 14457
  end

  def render_follow_button(usr)
    return "<button class='button-a flt-left login-req'>Follow</button>".html_safe unless logged_in?
    return "" if current_user.id == usr.id
    css_id = "follow_btn_#{usr.id}"
    content = if current_user.can_follow?(usr)
      "<button class='button-a flt-left follow-btn' id='#{css_id}' data-href='#{follow_user_path(usr.id)}'>Follow</button>"
    else # already following
      "<button class='button-a selected flt-left follow-btn' id='#{css_id}' data-href='#{unfollow_user_path(usr.id)}'>Following</button>"
    end
    content.html_safe
  end

  def render_flag_button(usr)
    return "" if current_user.id == usr.id
    content = if current_user.can_flag?(usr)
      "<a href='#' class='img-flag flt-left bg-tooltip'><label class='tooltip'>Flag</label></a>"
    else
      "<a href='#' class='img-flag selected flt-left bg-tooltip'><label class='tooltip'>Flagged</label></a>"
    end
    content.html_safe
  end

  def render_photo_like_button(f, liked=false)
    href = socialize_feed_path(f, :modal => liked ? 'unlike' : 'like')
    css_class = "mat4 #{'selected' if liked} bg-tooltip"
    css_id = (liked ? 'unlike_' : 'like_') + f.id.to_s
    content_tag(:a, :href => 'javascript:;', :class => css_class, :id => css_id, 'data-href' => href, :remote => true) do
      content_tag(:label, liked ? 'liked' : 'like', :class => 'tooltip')
    end
  end

  def render_font_autocomplete(fnts)
    content = ''.html_safe
    fnts.each do |f|
      content << content_tag(:li) do
        content_tag(:a, f[:name], :href => '#')
      end
    end
    content
  end

  def me?
    current_user.id == @user.id
  end

  def homepage?
    @homepage
  end

  def not_homepage?
    @homepage.nil?
  end

  # show user tagged font on profile-spotted page or most_agreed_font
  def show_appropriate_font_name(foto)
    fnt = if params[:type].to_s == 'spotted'
      @user.spotted_font(foto)
    elsif foto.sos_approved?
      foto.most_agreed_font
    end
    fnt.try(:display_name)
  end
end
