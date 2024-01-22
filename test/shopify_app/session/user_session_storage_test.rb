# frozen_string_literal: true

require "test_helper"

class UserMockSessionStore < ActiveRecord::Base
  include ShopifyApp::UserSessionStorage
end

module ShopifyApp
  class UserSessionStorageTest < ActiveSupport::TestCase
    TEST_SHOPIFY_USER_ID = 42
    TEST_SHOPIFY_DOMAIN = "example.myshopify.com"
    TEST_SHOPIFY_USER_TOKEN = "some-user-token-42"
    TEST_MERCHANT_SCOPES = "read_orders, write_products"

    test ".retrieve returns user session by id" do
      UserMockSessionStore.stubs(:find_by).returns(MockUserInstance.new(
        shopify_user_id: TEST_SHOPIFY_USER_ID,
        shopify_domain: TEST_SHOPIFY_DOMAIN,
        shopify_token: TEST_SHOPIFY_USER_TOKEN,
      ))

      session = UserMockSessionStore.retrieve(shopify_user_id: TEST_SHOPIFY_USER_ID)

      assert_equal TEST_SHOPIFY_DOMAIN, session.shop
      assert_equal TEST_SHOPIFY_USER_TOKEN, session.access_token
    end

    test ".retrieve_by_shopify_user_id returns user session by shopify_user_id" do
      instance = MockUserInstance.new(
        shopify_user_id: TEST_SHOPIFY_USER_ID,
        shopify_domain: TEST_SHOPIFY_DOMAIN,
        shopify_token: TEST_SHOPIFY_USER_TOKEN,
        api_version: ShopifyApp.configuration.api_version,
      )
      UserMockSessionStore.stubs(:find_by).with(shopify_user_id: TEST_SHOPIFY_USER_ID).returns(instance)

      expected_session = ShopifyAPI::Auth::Session.new(
        shop: instance.shopify_domain,
        access_token: instance.shopify_token,
      )

      user_id = TEST_SHOPIFY_USER_ID
      session = UserMockSessionStore.retrieve_by_shopify_user_id(user_id)
      assert_equal expected_session.shop, session.shop
      assert_equal expected_session.access_token, session.access_token
    end

    test ".destroy_by_shopify_user_id destroys user session by shopify_user_id" do
      UserMockSessionStore.expects(:destroy_by).with(shopify_user_id: TEST_SHOPIFY_USER_ID)

      UserMockSessionStore.destroy_by_shopify_user_id(TEST_SHOPIFY_USER_ID)
    end

    test ".store can store user session record" do
      mock_user_instance = MockUserInstance.new(shopify_user_id: 100)
      mock_user_instance.stubs(:save!).returns(true)

      UserMockSessionStore.stubs(:find_or_initialize_by).returns(mock_user_instance)

      saved_id = UserMockSessionStore.store(
        mock_session(
          shop: mock_user_instance.shopify_domain,
          scope: TEST_MERCHANT_SCOPES,
        ),
        mock_associated_user,
      )

      assert_equal "a-new-user_token!", mock_user_instance.shopify_token
      assert_equal mock_user_instance.id, saved_id
    end

    test ".retrieve returns nil for non-existent user" do
      user_id = "non-existent-user"
      UserMockSessionStore.stubs(:find_by).with(id: user_id).returns(nil)

      refute UserMockSessionStore.retrieve(user_id)
    end

    test ".retrieve_by_user_id returns nil for non-existent user" do
      user_id = "non-existent-user"
      UserMockSessionStore.stubs(:find_by).with(shopify_user_id: user_id).returns(nil)

      refute UserMockSessionStore.retrieve_by_shopify_user_id(user_id)
    end

    private

    def mock_associated_user
      ShopifyAPI::Auth::AssociatedUser.new(
        id: 100,
        first_name: "John",
        last_name: "Doe",
        email: "johndoe@email.com",
        email_verified: true,
        account_owner: false,
        locale: "en",
        collaborator: true,
      )
    end
  end
end
