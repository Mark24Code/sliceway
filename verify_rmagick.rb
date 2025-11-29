require 'rmagick'

puts "RMagick version: #{Magick::Version}"
puts "ImageMagick version: #{Magick::Magick_version}"

begin
  img = Magick::Image.new(100, 100) { self.background_color = "red" }
  puts "Successfully created an image with RMagick"
rescue => e
  puts "Failed to create image: #{e.message}"
end
