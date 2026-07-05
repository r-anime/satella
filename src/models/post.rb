class Post < ActiveRecord::Base
  self.table_name = 'posts'

  belongs_to :user, primary_key: "username", foreign_key: "author", optional: true
  has_many :comments, dependent: :destroy
  has_many :mod_actions, foreign_key: "target_post_id", dependent: :destroy
  has_one :flair_frequency_exemption, dependent: :destroy
end
