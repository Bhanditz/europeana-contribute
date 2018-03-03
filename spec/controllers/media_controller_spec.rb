# frozen_string_literal: true

require 'support/shared_examples/controllers/http_response_statuses'

RSpec.describe MediaController do
  describe 'GET show' do
    let(:action) { proc { get :show, params: params } }
    let(:params) { { uuid: uuid } }
    let(:web_resource) do
      create(:edm_web_resource).tap do |web_resource|
        web_resource.media.recreate_versions!(:thumb_400x400, :thumb_200x200)
      end
    end

    let(:uuid) { web_resource.uuid }

    context 'when unauthorised' do
      it_behaves_like 'HTTP 403 status'
    end

    context 'when authorised' do
      before do
        allow(controller).to receive(:current_user) { build(:user, role: :admin) }
      end

      context 'when web resource with UUID exists' do
        let(:location) { web_resource.media_url }
        it_behaves_like 'HTTP 303 status'

        context 'with size=w200' do
          let(:params) { { uuid: uuid, size: 'w200' } }
          let(:location) { web_resource.media.url(:thumb_200x200) }
          it_behaves_like 'HTTP 303 status'
        end

        context 'with size=w400' do
          let(:params) { { uuid: uuid, size: 'w400' } }
          let(:location) { web_resource.media.url(:thumb_400x400) }
          it_behaves_like 'HTTP 303 status'
        end
      end

      context 'when web resource with UUID does not exist' do
        let(:uuid) { SecureRandom.uuid }
        it_behaves_like 'HTTP 404 status'
      end
    end
  end
end