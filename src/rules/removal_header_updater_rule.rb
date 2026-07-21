module Rules
  class RemovalHeaderUpdaterRule < BaseRule
    def self.name
      "Removal Header Updater Rule"
    end

    def on_upsert
      rules_config.removal_header_template = config["comment"]
    end

    def priority
      99999
    end
  end
end
