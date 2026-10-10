class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :password, length: { minimum: 12 }, allow_nil: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
