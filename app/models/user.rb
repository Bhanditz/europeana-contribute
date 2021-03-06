# frozen_string_literal: true

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Blankness::Mongoid::Attributes
  include Blankness::Mongoid::Relations

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  # devise :database_authenticatable, :registerable,
  #        :recoverable, :rememberable, :trackable, :validatable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ''
  field :encrypted_password, type: String, default: ''

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  ## Confirmable
  # field :confirmation_token,   type: String
  # field :confirmed_at,         type: Time
  # field :confirmation_sent_at, type: Time
  # field :unconfirmed_email,    type: String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, type: Integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    type: String # Only if unlock strategy is :email or :both
  # field :locked_at,       type: Time

  field :role, type: Symbol

  has_many :contributions, class_name: 'Contribution', inverse_of: :created_by
  has_many :deleted_resources, class_name: 'DeletedResource', inverse_of: :deleted_by
  has_and_belongs_to_many :events, class_name: 'EDM::Event', inverse_of: nil

  rejects_blank :events

  def self.role_enum
    %i(admin events)
  end
  delegate :role_enum, to: :class

  validates :password_confirmation, presence: true, if: :encrypted_password_changed?
  validates :role, presence: true, inclusion: { in: User.role_enum }

  def active?
    case role
    when :events
      !events.size.zero?
    else
      true
    end
  end

  def destroyable?
    self != Current.user
  end
end
