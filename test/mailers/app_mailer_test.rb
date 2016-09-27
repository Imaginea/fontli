require 'test_helper'

describe 'AppMailer' do
  let(:user) { create(:user) }

  describe '#welcome_mail' do
    let(:mail) { AppMailer.welcome_mail(user) }

    it 'should have the provided subject' do
      mail.subject.must_equal 'Welcome to Fontli'
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided user email' do
      mail.to.must_equal [user.email]
    end
  end

  describe '#forgot_pass_mail' do
    let(:mail_params) { { 'username' => user.username, 'email' => user.email, 'password' => user.password } }
    let(:mail)        { AppMailer.forgot_pass_mail(mail_params) }

    it 'should have the provided subject' do
      mail.subject.must_equal 'Fontli: New password'
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided user email' do
      mail.to.must_equal [mail_params['email']]
    end
  end

  describe '#feedback_mail' do
    let(:feedback) { create(:suggestion, platform: 'iphone', os_version: '5.1', sugg_type: Faker::Lorem.word) }
    let(:mail)     { AppMailer.feedback_mail(feedback) }

    it 'should have the provided subject' do
      mail.subject.must_equal "Feedback API - #{Rails.env}: #{feedback.sugg_type}"
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided email address' do
      mail.to.must_equal %w(info@fontli.com)
    end
  end

  describe '#sos_requested_mail' do
    let(:sos)  { create(:photo, font_help: true) }
    let(:mail) { AppMailer.sos_requested_mail(sos.id) }

    it 'should have the provided subject' do
      mail.subject.must_equal 'Fontli: New SoS requested'
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided email address' do
      mail.to.must_equal SECURE_TREE['admin_mail_receivers']
    end
  end

  describe '#inactive_collection_creation_mail' do
    let(:collection) { create(:collection) }
    let(:mail)       { AppMailer.inactive_collection_creation_mail(collection.id) }

    it 'should have the provided subject' do
      mail.subject.must_equal 'Fontli: New Collection'
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided email address' do
      mail.to.must_equal SECURE_TREE['admin_mail_receivers']
    end
  end
end
