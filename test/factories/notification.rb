FactoryGirl.define do
  factory Notification do
    association :from_user, factory: :user
    association :to_user, factory: :user

    trait :for_like do
      association :notifiable, factory: :like
    end

    trait :for_comment do
      association :notifiable, factory: :comment
    end

    trait :for_mention do
      association :notifiable, factory: :mention
    end

    trait :for_font_tag do
      association :notifiable, factory: :font_tag
    end

    trait :for_agree do
      association :notifiable, factory: :agree
    end

    trait :for_follow do
      association :notifiable, factory: :follow
    end
  end
end
