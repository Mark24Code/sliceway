require 'sqlite3'
require 'active_record'
require 'fileutils'

# Determine database path
db_path = ENV['DB_PATH'] || 'db/development.sqlite3'
db_dir = File.dirname(db_path)

# Ensure db directory exists
FileUtils.mkdir_p(db_dir)

# Connect to database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: db_path
)

# Create tables if they don't exist
unless ActiveRecord::Base.connection.table_exists?(:projects)
  ActiveRecord::Schema.define do
    create_table :projects do |t|
      t.string :name
      t.string :psd_path
      t.string :export_path
      t.string :status, default: 'pending' # pending, processing, ready, error
      t.text :export_scales # JSON array of scales: ["1x", "2x", "4x"]
      t.integer :width  # PSD document width
      t.integer :height # PSD document height
      t.timestamps
    end
  end
end

# Add export_scales column if it doesn't exist (for existing databases)
unless ActiveRecord::Base.connection.column_exists?(:projects, :export_scales)
  ActiveRecord::Base.connection.add_column :projects, :export_scales, :text
end

unless ActiveRecord::Base.connection.table_exists?(:layers)
  ActiveRecord::Schema.define do
    create_table :layers do |t|
      t.integer :project_id
      t.string :resource_id
      t.string :name
      t.string :layer_type # slice, layer, group, text
      t.integer :x
      t.integer :y
      t.integer :width
      t.integer :height
      t.text :content # For text layers
      t.string :image_path # Relative path
      t.text :metadata # JSON for extra props
      t.integer :parent_id
    end
    add_index :layers, :project_id
    add_index :layers, [:project_id, :layer_type]
  end
end
