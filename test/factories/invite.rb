FactoryGirl.define do
  factory Invite do
    platform %w(twitter facebook).sample
    extuid   SecureRandom.hex(6)
    email    Faker::Internet.email
  end
end
