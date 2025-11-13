class ModAction < ActiveRecord::Base
  self.table_name = 'mod_actions'

  belongs_to :target_user, class_name: 'User', optional: true
  belongs_to :target_post, class_name: 'Post', optional: true
  belongs_to :target_comment, class_name: 'Comment', optional: true
end
