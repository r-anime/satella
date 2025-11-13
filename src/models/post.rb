class Post < ActiveRecord::Base
  self.table_name = 'posts'

  belongs_to :author, class_name: 'User', optional: true
  has_many :comments, dependent: :destroy
  has_many :mod_actions, foreign_key: "target_post_id", dependent: :destroy
end
