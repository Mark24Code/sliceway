require 'json'

class Project < ActiveRecord::Base
  has_many :layers, dependent: :destroy

  def as_json(options = {})
    super(options).merge({
      'file_size' => (psd_path && File.exist?(psd_path)) ? File.size(psd_path) : 0
    })
  end
end

class Layer < ActiveRecord::Base
  belongs_to :project
  # metadata is stored as JSON string in sqlite, so we might need to parse it manually or use a serializer if AR version supports it.
  # For simplicity in older AR or sqlite, we can just define getter/setter or use serialize.
  serialize :metadata, coder: JSON
  
  self.inheritance_column = :_type_disabled
end
