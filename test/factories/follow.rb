FactoryGirl.define do
  factory Follow do
    user
    association :follower, factory: :user
  end
end
