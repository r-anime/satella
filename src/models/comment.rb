class Comment < ActiveRecord::Base
  self.table_name = 'comments'

  belongs_to :author, class_name: 'User', optional: true
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :comments, class_name: "Comment", foreign_key: "parent_id", dependent: :destroy
  has_many :mod_actions, foreign_key: "target_comment_id", dependent: :destroy

  def self.is_in_source_corner?(comment_id36)
    top_level_body_matches?(comment_id36, "# Source Material Corner%", top_level_distinguished: true)
  end

  def self.top_level_body_matches?(comment_id36, top_level_body_matcher, top_level_distinguished: nil)
    sql = <<~SQL
      WITH RECURSIVE parent_chain AS (
        SELECT id, parent_id, body, distinguished
        FROM comments
        WHERE id36 = ?

        UNION ALL

        SELECT c.id, c.parent_id, c.body, c.distinguished
        FROM comments c
        JOIN parent_chain a ON c.id = a.parent_id
      )
      SELECT EXISTS (
        SELECT 1 FROM parent_chain
        WHERE parent_id IS NULL
        AND body ILIKE ?
        #{top_level_distinguished.nil? ? "" : "AND distinguished = ?"}
      ) AS result;
    SQL
    args = [sql, comment_id36, top_level_body_matcher]
    args << top_level_distinguished unless top_level_distinguished.nil?
    ActiveRecord::Base.connection.select_value(ActiveRecord::Base.send(:sanitize_sql_array, args))
  end

  def is_in_source_corner?
    self.class.is_in_source_corner?(id)
  end

  def top_level_body_matches?(top_level_body_matcher)
    self.class.top_level_body_matches?(id, top_level_body_matcher)
  end
end
