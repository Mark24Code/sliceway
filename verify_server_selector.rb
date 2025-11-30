require 'net/http'
require 'json'
require 'uri'

puts "Verification of /api/system/directories"
puts "---------------------------------------"

# 1. Start server (assumed running or we just check code)
# We will check if the endpoint is defined in app.rb
puts "\nChecking if app.rb has the endpoint..."
content = File.read('/Users/tanling/Downloads/sliceway/app.rb')
if content.include?("get '/api/system/directories' do")
  puts "✅ Endpoint definition found in app.rb"
else
  puts "❌ Endpoint definition NOT found in app.rb"
end

# 2. Check if ServerFolderSelector component exists
puts "\nChecking if ServerFolderSelector component exists..."
if File.exist?('/Users/tanling/Downloads/sliceway/frontend/src/components/ServerFolderSelector/index.tsx')
  puts "✅ ServerFolderSelector component found"
else
  puts "❌ ServerFolderSelector component NOT found"
end

# 3. Check if FolderSelector uses ServerFolderSelector
puts "\nChecking if FolderSelector uses ServerFolderSelector..."
fs_content = File.read('/Users/tanling/Downloads/sliceway/frontend/src/components/FolderSelector/index.tsx')
if fs_content.include?("import ServerFolderSelector from '../ServerFolderSelector'")
  puts "✅ FolderSelector imports ServerFolderSelector"
else
  puts "❌ FolderSelector does NOT import ServerFolderSelector"
end
