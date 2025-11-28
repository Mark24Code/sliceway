require 'json'
require 'etc'

class Project < ActiveRecord::Base
  has_many :layers, dependent: :destroy
  serialize :export_scales, coder: JSON

  validates :processing_cores, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: ->(project) { project.max_available_cores - 1 }
  }

  def as_json(options = {})
    super(options).merge({
      'file_size' => (psd_path && File.exist?(psd_path)) ? File.size(psd_path) : 0
    })
  end

  # Get maximum available CPU cores
  def max_available_cores
    @max_available_cores ||= begin
      cores = Etc.nprocessors
      cores > 1 ? cores : 1
    end
  end
end

class Layer < ActiveRecord::Base
  belongs_to :project
  # metadata is stored as JSON string in sqlite, so we might need to parse it manually or use a serializer if AR version supports it.
  # For simplicity in older AR or sqlite, we can just define getter/setter or use serialize.
  serialize :metadata, coder: JSON
  
  self.inheritance_column = :_type_disabled
end
