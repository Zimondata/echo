require "digest"

class EchoServiceToken < ApplicationRecord
  INCOMPATIBLE_SCOPE_SETS = [ %w[echo:trusted evidence:verify] ].freeze

  belongs_to :user

  validates :name, :token_digest, presence: true
  validates :token_digest, uniqueness: true
  validate :scopes_do_not_mix_execution_and_verification

  scope :active, -> { where(revoked_at: nil) }

  def self.issue!(user:, name:, scopes:)
    raw_token = SecureRandom.urlsafe_base64(36)
    credential = create!(
      user: user,
      name: name,
      token_digest: digest(raw_token),
      scopes: Array(scopes).map(&:to_s).uniq
    )
    [ credential, raw_token ]
  end

  def self.authenticate(raw_token, scope:)
    return if raw_token.blank?

    candidate_digest = digest(raw_token)
    credential = active.find_by(token_digest: candidate_digest)
    return unless credential
    return unless ActiveSupport::SecurityUtils.secure_compare(credential.token_digest, candidate_digest)
    return unless credential.scopes.include?(scope)

    credential.touch(:last_used_at)
    credential
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
  private_class_method :digest

  private

  def scopes_do_not_mix_execution_and_verification
    normalized = Array(scopes).map(&:to_s)
    return unless INCOMPATIBLE_SCOPE_SETS.any? { |set| (set - normalized).empty? }

    errors.add(:scopes, "cannot combine execution and evidence verification")
  end
end
