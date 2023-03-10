# frozen_string_literal: true

# https://github.com/Drieam/LtiLauncher
# MIT License
#
# Copyright (c) 2019 Drieam
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

##
# This class contains functionality needed for signing messages
# and publishing JWK[s].
#
# The last three created keypairs are considered valid, so creating a new Keypair
# will invalidate the second to last created Keypair.
#
#   Keypair.create!
#
# If you need to sign messages, use the 'current' Keypair for this. This method
# performs the rotation of the keypairs if required.
#
#   Keypair.current
#
# You can also use the `jwt_encode` and `jwt_decode` methods directly to encode and
# securely decode your payloads
#
#   payload = 'foobar'
#   id_token = Keypair.jwt_encode(payload)
#   decoded = Keypair.jwt_decode(id_token)
#
# Borrowed from: https://github.com/Drieam/LtiLauncher
class Keypair < ApplicationRecord
  ALGORITHM = 'RS256'
  encrypts :keypair
  after_initialize :set_keypair

  validates :keypair, presence: true
  validates :jwk_kid, presence: true

  # The last 3 keypairs are considered valid and can be used
  # to validate signatures and export public jwks of.
  # It uses a subquery to make sure a find_by actually searches only the valid 3 ones.
  scope :valid, -> { where(id: order(created_at: :desc).limit(3)) }

  # This should be the keypair used to sign messages.
  def self.current
    order(:created_at).where(arel_table[:created_at].gt(1.month.ago)).last || create!
  end

  # Encodes the payload with the current keypair
  def self.jwt_encode(payload)
    current.jwt_encode(payload)
  end

  # Decodes the payload and verifies the signature against the current valid keypairs
  def self.jwt_decode(id_token)
    jwks = { keys: valid.map(&:public_jwk_export) }
    JWT.decode(id_token, nil, true, algorithm: ALGORITHM, jwks: jwks).first
  end

  # Encodes the payload with this keypair
  def jwt_encode(payload)
    JWT.encode(payload, private_key, ALGORITHM, kid: jwk_kid)
  end

  # We append the `alg`, and `use` parameters to our JWK to indicate
  # that our intended use is to generate signatures using RS256.
  #
  # The "alg" (algorithm) parameter identifies the algorithm
  # intended for use with the key. Use of this member is OPTIONAL.
  #
  # The "use" (public key use) parameter identifies the intended use of
  # the public key. Use of the "use" member is OPTIONAL, unless the
  # application requires its presence.
  #
  # See: https://tools.ietf.org/html/rfc7517#section-4.4
  #
  # The IMS Security framework specifies: The `alg` value SHOULD be the default of RS256.
  #
  # See: https://www.imsglobal.org/spec/security/v1p0#authentication-response-validation
  def public_jwk_export
    public_jwk.export.merge(
      alg: ALGORITHM,
      use: 'sig'
    )
  end

  # Returns an `OpenSSL::PKey::RSA` instance loaded with our keypair.
  def private_key
    OpenSSL::PKey::RSA.new(keypair)
  end

  # Returns an `OpenSSL::PKey::RSA` instance loaded with the public part of our keypair.
  delegate :public_key, to: :private_key

  private

  # Returns a JWT::JWK instance with the public part of our keypair.
  def public_jwk
    JWT::JWK.create_from(public_key)
  end

  # Generate a new keypair with a key_size of 2048. Keys less
  # than 1024 bits should be considered insecure.
  #
  # See: https://ruby-doc.org/stdlib-2.6.5/libdoc/openssl/rdoc/OpenSSL/PKey/RSA.html#method-c-new
  def set_keypair
    # The generated keypair is stored in PEM encoding.
    self.keypair ||= OpenSSL::PKey::RSA.new(2048).to_pem
    self.jwk_kid = public_jwk.kid
  end
end
