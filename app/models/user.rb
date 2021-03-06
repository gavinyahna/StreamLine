class User < ActiveRecord::Base
  has_many :tasks
  has_many :notes

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = Time.at(auth.credentials.expires_at)
      user.current_login = DateTime.now
      if (user.populated.nil?)
        user.populated = false
      end
      user.oauth_refresh_token = auth.credentials.refresh_token
      user.save!
    end
  end

  def expired?
    oauth_expires_at < Time.current.to_i
  end
end