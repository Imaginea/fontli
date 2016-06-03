class ApiSession
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include MongoExtensions

  field :device_id, :type => String
  field :auth_token, :type => String
  field :expires_at, :type => Time

  index :auth_token => 1, :device_id => 1

  SESSION_EXPIRY_TIME = 40.weeks
  
  belongs_to :user, :index => true
  
  validates :user_id, :device_id, :presence => true
  
  def self.[](token, devic_id)
    where(:auth_token => token, :device_id => devic_id).first
  end
  
  def activate
    self.auth_token = Digest::MD5.hexdigest(SecureRandom.urlsafe_base64 + user_id)
    self.expires_at = current_time + SESSION_EXPIRY_TIME
    self.save ? CGI.escape(token_str) : [nil, :unable_to_save]
  end
  
  def deactivate
    self.auth_token = nil
    self.expires_at = current_time
    
    if self.save
      user.update_attribute(:iphone_token, nil)
    else
      [nil, :unable_to_save]
    end
  end
  
  def active?
    self.expires_at > current_time
  end
  
  private
  
  def token_str
    auth_token + '||'
  end
end
