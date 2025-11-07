require_relative './reddit_kind'

class RuleResult
  attr_reader :rule_module, :reddit_kind, :actions

  def initialize(rule_module:, reddit_kind:, actions:)
    @rule_module = rule_module
    @reddit_kind = reddit_kind
    @actions = actions
  end

  module ActionLevel
    REMOVE = :remove
    REPORT = :report
    MOD_COMMENT = :mod_comment
    COMMENT = :comment
    REFLAIR = :reflair
    CUSTOM = :custom
    NOTHING = :nothing
  end

  class BaseAction
    attr_reader :rule_module, :level, :rabbit_message

    def initialize(rule_module:, level:, rabbit_message:)
      @rule_module = rule_module
      @level = level
      @rabbit_message = rabbit_message
    end
  end

  class RemoveAction < BaseAction
    attr_reader :comment_templates

    def initialize(rule_module:, rabbit_message:, comment_templates: [], sticky: false)
      super(rule_module:, level: ActionLevel::REMOVE, rabbit_message:)
      @comment_templates = comment_templates
      @sticky = sticky
    end

    def sticky?
      @sticky
    end
  end

  class ReportAction < BaseAction
    attr_reader :report_template

    def initialize(rule_module:, rabbit_message:, report_template:)
      super(rule_module:, level: ActionLevel::REPORT, rabbit_message:)
      @report_template = report_template
    end
  end

  class ModCommentAction < BaseAction
    attr_reader :comment_templates

    def initialize(rule_module:, rabbit_message:, comment_templates:, sticky: false)
      super(rule_module:, level: ActionLevel::MOD_COMMENT, rabbit_message:)
      @comment_templates = comment_templates
      @sticky = sticky
    end

    def sticky?
      @sticky
    end
  end

  class CommentAction < BaseAction
    attr_reader :comment_templates

    def initialize(rule_module:, rabbit_message:, comment_templates:)
      super(rule_module:, level: ActionLevel::COMMENT, rabbit_message:)
      @comment_templates = comment_templates
    end
  end

  class ReflairAction < BaseAction
    attr_reader :new_flair

    def initialize(rule_module:, rabbit_message:, new_flair:)
      super(rule_module:, level: ActionLevel::REMOVE, rabbit_message:)
      @new_flair = new_flair
    end
  end

  class CustomAction < BaseAction
    attr_reader :args

    def initialize(rule_module:, rabbit_message:, args: nil)
      super(rule_module:, level: ActionLevel::REMOVE, rabbit_message:)
      @args = args
    end
  end

  class NoAction < BaseAction
    def initialize(rule_module:, rabbit_message:)
      super(rule_module:, level: ActionLevel::NOTHING, rabbit_message:)
    end
  end
end
