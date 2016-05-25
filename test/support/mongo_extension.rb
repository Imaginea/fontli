module MongoExtensions
  def current_user
    controller.try(:current_user) || FactoryGirl.create(:user)
  end

  def request_domain
    'http://localhost:3000'
  end
end
