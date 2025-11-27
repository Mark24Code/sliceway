require 'sqlite3'
require 'active_record'
require 'fileutils'

# Ensure db directory exists
FileUtils.mkdir_p('db')

# Connect to database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/development.sqlite3'
)

# Create tables if they don't exist
unless ActiveRecord::Base.connection.table_exists?(:projects)
  ActiveRecord::Schema.define do
    create_table :projects do |t|
      t.string :name
      t.string :psd_path
      t.string :export_path
      t.string :status, default: 'pending' # pending, processing, ready, error
      t.timestamps
    end
  end
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
