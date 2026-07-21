module Rules
  class RemovalFooterUpdaterRule < BaseRule
    def self.name
      "Removal Footer Updater Rule"
    end

    def on_upsert
      rules_config.removal_footer_template = config["comment"]
    end

    def priority
      99999
    end
  end
end
