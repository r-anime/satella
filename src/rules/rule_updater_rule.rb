class RuleUpdaterRule < BaseRule
  ACTION = 'wikirevise'
  DETAIL = 'Updated AutoModerator configuration'

  def name
    "Rule Updater Rule"
  end

  # This should not do anything
  def on_upsert
  end

  def priority
    99999
  end

  def no_automod_config?
    true
  end

  def static_mod_action_check?(message)
    ACTION == message[:reddit][:action] && DETAIL == message[:reddit][:details]
  end

  def mod_action_check(message)
    result_action(message)
  end

  def result_action(message)
    $logger.debug "#{self.class.name} Actioning message: #{[:mod_id36, :action, :details].map{[it, message[:reddit][it]]}.to_h}"
    rules_config.fetch_config!
  end
end
