FactoryGirl.define do
  factory UserFlag do
    user
    association :from_user, factory: :user
  end
end
