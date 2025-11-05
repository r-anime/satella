class SourceMaterialCornerRule < BaseRule
  def name
    "Source Material Corner Rule"
  end

  def on_upsert
    puts "loaded SMC rules: #{config}"
  end

  def static_post_check?(reddit_object)
    false
  end
end
