class User < ActiveRecord::Base
  self.table_name = 'users'

  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :mod_actions, foreign_key: "target_user", dependent: :destroy
end
