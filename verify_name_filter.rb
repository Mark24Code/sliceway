puts "Verification of Name Filter in FilterList.tsx"
puts "--------------------------------------------"

content = File.read('/Users/tanling/Downloads/sliceway/frontend/src/components/InteractiveView/FilterList.tsx')

# Check for state definition
if content.include?("const [nameFilter, setNameFilter] = useState('');")
  puts "✅ State definition found"
else
  puts "❌ State definition NOT found"
end

# Check for Input import
if content.include?("import { Tabs, Card, Checkbox, Button, message, Select, Space, Input } from 'antd';")
  puts "✅ Input import found"
else
  puts "❌ Input import NOT found"
end

# Check for Input component usage
if content.include?("<Input") && content.include?("placeholder=\"搜索图层名称\"")
  puts "✅ Input component usage found"
else
  puts "❌ Input component usage NOT found"
end

# Check for filtering logic
if content.include?("list = list.filter(l => l.name.toLowerCase().includes(lowerName));")
  puts "✅ Filtering logic found"
else
  puts "❌ Filtering logic NOT found"
end
