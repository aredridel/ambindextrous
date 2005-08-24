#!/usr/bin/ruby

require 'RMagick'
require 'cgi'
require 'fcgi'

format = 'JPEG'

FCGI.each_cgi do |cgi|
	begin
		image = cgi.env_table['PATH_INFO']
		size = image.split('/')[1]
		image = image.split('/')[2..-1].join('/')

		# file = File.join(systempath, image)
		file = image
		img = Magick::Image.read(file).first
		img.change_geometry!(size) { |cols, rows| img.thumbnail! cols, rows }
		img.format = format.upcase
		content = img.to_blob
		puts "Content-type: image/#{format.downcase}\n"
		puts "Content-Length: #{content.size}\n\n"
		puts content
	rescue Exception => e
		puts "Content-type: text/plain\n\nError #{e}"
	end
end
