FactoryGirl.define do
  factory Font do
    family_unique_id { SecureRandom.hex }
    family_id        { SecureRandom.hex }
    photo
    user
  end
end
