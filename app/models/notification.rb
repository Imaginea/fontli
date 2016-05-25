require 'uri'
require 'net/http'

class Notification
  include Mongoid::Document
  include Mongoid::Timestamps

  field :unread, :type => Boolean, :default => true
  # store related photo_id(for like) or font_id(for font_tag) to avoid additional DB hits
  field :extid, :type => String

  belongs_to :from_user, :class_name => 'User', :inverse_of => :sent_notifications
  belongs_to :to_user, :class_name => 'User', :index => true, :inverse_of => :notifications
  belongs_to :notifiable, :polymorphic => true, :index => true

  validates :from_user_id, :to_user_id, :presence => true
  validates :notifiable_id, :notifiable_type, :presence => true

  default_scope desc(:updated_at, :unread)
  scope :unread, where(:unread => true)

  after_create :send_apn

  class << self
    def find_for(tgt_id, extid, not_type)
      self.where(:to_user_id => tgt_id, :extid => extid, :notifiable_type => not_type).first
    end
  end

  def message
    frm_usr = self.from_user
    case self.notifiable_type.to_s
    when /Like/
      "#{frm_usr.username} liked your post."
    when /Comment/
      to_usr = self.to_user
      cntxt = self.notifiable.photo.user_id == to_usr.id ? 'your' : "#{to_usr.username}'s"
      "#{frm_usr.username} commented on #{cntxt} post."
    when /Mention/
      cntxt = self.notifiable.mentionable_type == 'Comment' ? 'comment' : 'post'
      "#{frm_usr.username} mentioned you in a #{cntxt}."
    when /FontTag/
      "#{frm_usr.username} spotted on your post."
    when /Agree/
      "#{frm_usr.username} agreed your spotting."
    when /Follow/
      "#{frm_usr.username} started following your feed."
    else
      "You have an unread notification!"
    end
  end

  def target
    notifble = self.notifiable
    case self.notifiable_type.to_s
    when /Like|Comment/
      notifble.photo
    when /FontTag|Agree/
      notifble.font.photo
    when /Mention/
      mentnble = notifble.mentionable
      mentnble.is_a?(Comment) ? mentnble.photo : mentnble
    when /Follow/
      notifble.user
    end
  end

private

  # sends push notification for every new notification
  def send_apn
    to_usr = self.to_user
    # check for windows toast url if iphone_token is blank.
    return send_wp_toast_notif if to_usr.iphone_token.blank?
    notif_cnt = to_usr.notifications.unread.count
    opts = { :badge => notif_cnt, :alert => self.message, :sound => true }
    APN.notify_async(to_usr.iphone_token, opts)
    true
  rescue Exception => e
    Rails.logger.error { "#{e.message} #{e.backtrace.join("\n")}" }
  end
  
  # TODO: Background this.
  def send_wp_toast_notif
    wp_url = self.to_user.wp_toast_url
    # check for android device
    return send_android_notif if wp_url.blank?

    u = URI.parse(wp_url)
    req = Net::HTTP::Post.new(u.path)

    req_xml = '<?xml version="1.0" encoding="utf-8"?>'
    req_xml << '<wp:Notification xmlns:wp="WPNotification">'
    req_xml << '<wp:Toast>'
    req_xml << '<wp:Text1>Fontli</wp:Text1>'
    req_xml << "<wp:Text2>#{self.message}</wp:Text2>"
    req_xml << "<wp:Param>/UserProfile/UserUpdate.xaml</wp:Param>"
    req_xml << '</wp:Toast>'
    req_xml << '</wp:Notification>'

    req.content_type = 'text/xml'
    req['X-WindowsPhone-Target'] = 'toast'
    req['X-NotificationClass'] = '2'
    req.body = req_xml

    resp = Net::HTTP.start(u.host, u.port) do |http|
      http.request(req)
    end
    true
  end

  def send_android_notif
    regis_ids = [self.to_user.android_registration_id]
    return true if regis_ids.blank?

    # additionally send notifiable_type and photo_id/user_id
    targt = self.target
    options = { data: {
      message: self.message,
      notifiable_type: self.notifiable_type,
      target_id: targt.try(:id),
      target_type: targt.try(:class).to_s
    } }

    gcm = GCM.new(SECURE_TREE['gcm_api_key'])
    response = gcm.send(regis_ids, options)
    true
  end
end
