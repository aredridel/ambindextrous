#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'RMagick'
require 'cgi'
require 'fcgi'
require 'uri-open'
require 'cgi/pathmap'

format = 'JPEG'

FCGI.each do |fcgi|
	begin
		host = req.env['HTTP_HOST']
		url = URI.parse("http://#{host}/#{req.env['REQUEST_URI']}")
		image = fcgi.env['PATH_INFO']
		size = image.split('/')[1]
		image = image.split('/')[2..-1].join('/')

		# file = File.join(systempath, image)
		file = image
		img = Magick::Image.read_blob(file).first
		img.change_geometry!(size) { |cols, rows| img.thumbnail! cols, rows }
		img.format = format.upcase
		content = img.to_blob
		fcgi.out << "Content-type: image/#{format.downcase}\n"
		fcgi.out << "Content-Length: #{content.size}\n\n"
		fcgi.out << content
	rescue Exception => e
		fcgi.out << "Content-type: text/plain\n\nError #{e}"
	end
end
