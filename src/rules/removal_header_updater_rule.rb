module Rules
  class RemovalHeaderUpdaterRule < BaseRule
    def name
      "Removal Header Updater Rule"
    end

    def on_upsert
      rules_config.removal_header_template = config["comment"]
    end
  end
end
