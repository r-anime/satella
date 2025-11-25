module Rules
  class RemovalFooterUpdaterRule < BaseRule
    def name
      "Removal Footer Updater Rule"
    end

    def on_upsert
      rules_config.removal_footer_template = config["comment"]
    end
  end
end
