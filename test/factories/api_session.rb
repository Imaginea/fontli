FactoryGirl.define do
  factory ApiSession do
    device_id { SecureRandom.hex }
    user
  end
end
