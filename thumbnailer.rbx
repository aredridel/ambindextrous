#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'RMagick'
require 'cgi'
require 'fcgi'
require 'cgi/pathmap'
require 'cacher/freedesktopthumbnailer'

format = 'JPEG'

FCGI.each do |fcgi|
	begin
		host = fcgi.env['HTTP_HOST']
		url = URI.parse("http://#{host}/#{fcgi.env['REQUEST_URI']}")
		image = fcgi.env['PATH_INFO']
		size = image.split('/')[1]
		image = image.split('/')[2..-1].join('/')
		file = fcgi.path_translated('/' + image)
		STDERR.puts(file)
		cacher = FreedesktopThumbnailer.new(size)
		content = cacher.thumbnail(file, format) 
		fcgi.out << "Content-type: image/#{format.downcase}\n"
		fcgi.out << "Content-Length: #{content.size}\n\n"
		fcgi.out << content
	rescue Exception => e
		fcgi.out << "Content-type: text/plain\n\nError #{e}"
	end
	fcgi.finish
end
