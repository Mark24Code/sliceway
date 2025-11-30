# Test script to verify encoding fix

# Simulate a string with invalid encoding (ASCII-8BIT with high bit set)
# \xE9 is é in ISO-8859-1, but invalid in UTF-8 if interpreted as such without conversion
bad_string = "\xE9".force_encoding('ASCII-8BIT')

puts "Original encoding: #{bad_string.encoding}"
puts "Original valid?: #{bad_string.valid_encoding?}"

filename = bad_string.dup

if filename
  filename.force_encoding('UTF-8')
  unless filename.valid_encoding?
    puts "Detected invalid encoding, fixing..."
    filename.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end
end

puts "Final encoding: #{filename.encoding}"
puts "Final valid?: #{filename.valid_encoding?}"
puts "Final content: #{filename.inspect}"

# Test with a valid UTF-8 string
good_string = "test_é".force_encoding('UTF-8')
filename2 = good_string.dup

if filename2
  filename2.force_encoding('UTF-8')
  unless filename2.valid_encoding?
    filename2.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end
end

puts "Good string final encoding: #{filename2.encoding}"
puts "Good string valid?: #{filename2.valid_encoding?}"
puts "Good string content: #{filename2.inspect}"
