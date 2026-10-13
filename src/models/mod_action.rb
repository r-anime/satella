class ModAction < ActiveRecord::Base
  self.table_name = 'mod_actions'

  belongs_to :target_user, class_name: 'User', foreign_key: 'target_user', primary_key: 'username', optional: true
  belongs_to :target_post, class_name: 'Post', optional: true
  belongs_to :target_comment, class_name: 'Comment', optional: true
end
