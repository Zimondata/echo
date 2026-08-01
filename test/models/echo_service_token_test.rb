require "test_helper"

class EchoServiceTokenTest < ActiveSupport::TestCase
  test "stores only a digest and authenticates the one-time raw token" do
    credential, raw_token = EchoServiceToken.issue!(
      user: users(:john),
      name: "Hermes local bridge",
      scopes: [ "echo:trusted" ]
    )

    assert raw_token.present?
    assert_not_equal raw_token, credential.token_digest
    assert_nil EchoServiceToken.find_by(token_digest: raw_token)
    assert_equal credential, EchoServiceToken.authenticate(raw_token, scope: "echo:trusted")
    assert_nil EchoServiceToken.authenticate(raw_token, scope: "admin")
  end

  test "execution and verification scopes cannot share one credential" do
    assert_raises(ActiveRecord::RecordInvalid) do
      EchoServiceToken.issue!(
        user: users(:john),
        name: "Conflicted principal",
        scopes: %w[echo:trusted evidence:verify]
      )
    end
  end
end
