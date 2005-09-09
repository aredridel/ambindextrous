#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'cgi'
require 'fcgi'
require 'cgi/pathmap'
require 'cacher/webthumbnailer'

FCGI.each do |fcgi|
	begin
		host = fcgi.env['HTTP_HOST']
		url = URI.parse("http://#{host}/#{fcgi.env['REQUEST_URI']}")
		image = fcgi.env['PATH_INFO']
		size = image.split('/')[1]
		image = image.split('/')[2..-1].join('/')
		file = fcgi.path_translated('/' + image)
		STDERR.puts(file)
		cacher = WebThumbnailer.new(size)
		content = cacher.thumbnail(file) 
		fcgi.out << "Content-type: image/jpeg\n"
		fcgi.out << "Content-Length: #{content.size}\n\n"
		fcgi.out << content
	rescue Exception => e
		fcgi.out << "Content-type: text/plain\n\nError #{e}"
	end
	fcgi.finish
	GC.start
end
