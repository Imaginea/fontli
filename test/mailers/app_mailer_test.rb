require 'test_helper'

describe 'AppMailer' do
  describe '#sos_requested_mail' do
    let(:sos)  { create(:photo, font_help: true) }
    let(:mail) { AppMailer.sos_requested_mail(sos.id) }

    it 'should have the provide subject' do
      mail.subject.must_equal 'Fontli: New SoS requested'
    end

    it 'should send email with from address' do
      mail.from.must_equal %w(noreply@fontli.com)
    end

    it 'should send email to provided email address' do
      mail.to.must_equal SECURE_TREE['sos_notification_receivers']
    end
  end
end
