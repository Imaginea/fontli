FactoryGirl.define do
  factory Follow do
    user
    follower_id { create(:user).id }
  end
end
