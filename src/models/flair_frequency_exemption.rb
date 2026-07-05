class FlairFrequencyExemption < ActiveRecord::Base
  self.table_name = 'flair_frequency_exemptions'

  belongs_to :post
end
