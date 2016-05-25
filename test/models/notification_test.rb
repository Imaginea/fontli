require 'test_helper'

describe Notification do
  let(:notification)          { create(:notification, :for_follow, extid: SecureRandom.hex(6)) }
  let(:read_notification)     { create(:notification, :for_follow, unread: false) }
  let(:like_notification)     { create(:notification, :for_like) }
  let(:comment_notification)  { create(:notification, :for_comment) }
  let(:mention_notification)  { create(:notification, :for_mention) }
  let(:font_tag_notification) { create(:notification, :for_font_tag) }
  let(:agree_notification)    { create(:notification, :for_agree) }

  subject { Notification }

  it { must have_fields(:unread).of_type(Boolean).with_default_value(true) }
  it { must have_fields(:extid).of_type(String) }

  it { must belong_to(:from_user).as_inverse_of(:sent_notifications) }
  it { must belong_to(:to_user).as_inverse_of(:notifications) }
  it { must belong_to(:notifiable) }

  it { must have_index_for(:to_user_id) }
  it { must have_index_for(:notifiable_id, :notifiable_type) }

  it { must validate_presence_of(:from_user_id) }
  it { must validate_presence_of(:to_user_id) }
  it { must validate_presence_of(:notifiable_id) }
  it { must validate_presence_of(:notifiable_type) }

  describe 'scope' do
    before do
      notification
      read_notification
    end

    it 'should return the unread notifications' do
      Notification.unread.must_include notification
    end

    it 'should not return read notifications' do
      Notification.unread.wont_include read_notification
    end
  end

  describe '.find_for' do
    it 'should return a notification matching provided criteria' do
      Notification.find_for(notification.to_user_id, notification.extid, notification.notifiable_type).must_equal notification
    end

    it 'should not return a notification not matching provided criteria' do
      Notification.find_for(notification.to_user_id, notification.extid, notification.notifiable_type).wont_equal read_notification
    end
  end

  describe '#message' do
    let(:unknown_notification) { create(:notification, notifiable: create(:user)) }

    it 'should return message for like' do
      like_notification.message.must_equal "#{like_notification.from_user.username} liked your post."
    end

    it 'should return message for comment' do
      comment_notification.message.must_equal "#{comment_notification.from_user.username} commented on #{comment_notification.to_user.username}'s post."
    end

    it 'should return message for mention' do
      mention_notification.message.must_equal "#{mention_notification.from_user.username} mentioned you in a post."
    end

    it 'should return message for font_tag' do
      font_tag_notification.message.must_equal "#{font_tag_notification.from_user.username} spotted on your post."
    end

    it 'should return message for agree' do
      agree_notification.message.must_equal "#{agree_notification.from_user.username} agreed your spotting."
    end

    it 'should return message for follow' do
      notification.message.must_equal "#{notification.from_user.username} started following your feed."
    end

    it 'should return message for unknown notifiable type' do
      unknown_notification.message.must_equal 'You have an unread notification!'
    end
  end

  describe '#target' do
    it 'should return target for like' do
      like_notification.target.must_equal like_notification.notifiable.photo
    end

    it 'should return target for comment' do
      comment_notification.target.must_equal comment_notification.notifiable.photo
    end

    it 'should return target for font_tag' do
      font_tag_notification.target.must_equal font_tag_notification.notifiable.font.photo
    end

    it 'should return target for agree' do
      agree_notification.target.must_equal agree_notification.notifiable.font.photo
    end

    it 'should return target for mention' do
      mention_notification.target.must_equal mention_notification.notifiable.mentionable
    end

    it 'should return target for follow' do
      notification.target.must_equal notification.notifiable.user
    end
  end

  describe '#send_apn' do
    let(:notification) { create(:notification, :for_follow, to_user: create(:user, iphone_token: SecureRandom.hex(3))) }

    it 'should return true' do
      APN.stubs(:notify_async).returns(true)
      notification.send(:send_apn).must_equal true
    end
  end

  describe '#send_wp_toast_notif' do
    let(:notification) { create(:notification, :for_follow, to_user: create(:user, wp_toast_url: 'http://haag.biz/sedrick.parisian')) }

    it 'should return true' do
      notification.send(:send_wp_toast_notif).must_equal true
    end
  end
end
