#! /usr/bin/ruby

require 'fcgi'
require 'logger'
require 'amrita/template'
require 'etc'
require 'xattr'
require 'RMagick'
require 'digest/md5'
require 'fileutils'

LOGGER = Logger.new(STDERR)

class XMLTemplateFile < Amrita::TemplateFile
	def initialize(file)
		super(file)
		self.xml = true
		self.asxml = true
		self.expand_attr = true
		self.amrita_id = 'amrita:id'
		self.use_compiler = true
	end
end

class String
	def urldecode
		self.gsub(/%([A-Fa-f0-9]{2})/) {|s| [$1.hex].pack("C") }
	end
	def formdecode
		self.gsub('+', ' ').urldecode
	end
	def urlencode
		self.gsub('%', '%25').gsub(' ', '%20').gsub('?', '%3F')
	end
end

class Integer
	def as_filesize
		if self > 2**30
			("%.2f" % (self.to_f / 2**30)) << ' gb'
		elsif self > 2**20
			("%.2f" % (self.to_f / 2**20)) << ' mb'
		elsif self > 2**10
			("%.2f" % (self.to_f / 2**10)) << ' kb'
		else
			(self.to_s) << ' bytes'
		end
	end
end

class File
	def self.contentsize(filename)
		stat = File.stat(filename)
		if(stat.directory?)
			dc = 0
			fc = 0
			images = []
			begin
				Dir.open(filename).each do |d|
					if(d[0] != '.'[0])
						if File.stat(File.join(filename, d)).directory? 
							dc += 1
						else
							fc += 1
							if /.(jpg|jpeg|gif|png|tif|tiff|svg)$/ =~ d
								images << d
							end
						end
					end
				end
				Amrita::SanitizedString.new [  # FIXME: this escaping is too simplistic
					if dc > 0 
						"#{dc} #{if dc > 1 then "directories" else "directory" end}," 
					else 
						"" 
					end,
					"#{fc} #{if fc > 1 then "files" else "file" end}",
					if images.empty? 
						"" 
					else 
						images.map { |i| 
							f = File.join(File.basename(filename), i)
							"<a href='#{f}'><img src='/global-site-overlay/thumbnailer.rbx/128x128/#{f}' alt='' title='#{i}' /></a>" 
						}.join(' ')
					end
				].join(' ')
			rescue
				'?'
			end
		else
			stat.size.as_filesize
		end
	end
end

class FCGILet
	attr_accessor :out, :in, :query, :path, :docroot, :systempath, :mode, :host, :url
	def initialize(req)
		self.docroot = req.env['DOCUMENT_ROOT']
		self.query = req.env['QUERY_STRING']
		self.host = req.env['HTTP_HOST']
		self.url = "http://#{host}/#{req.env['REQUEST_URI']}"
		if(query.empty?)
			self.path = req.env['REQUEST_URI'].urldecode
		else
			self.path = req.env['REQUEST_URI'].split('?')[0].urldecode
		end
		if path =~ %r{/~([^/]+)}
			self.docroot = File.join(Etc.getpwnam($1).dir, (if host =~ /evil/: 'evil' else 'web' end))
			path.gsub! %r{/~([^/])+/}, '/'
		end
		self.systempath = File.join(docroot, path)
		
		self.out = req.out
		self.in = req.in
		
		self.mode = req.env['REQUEST_METHOD']
	end
end

class Ambindextrous < FCGILet
	attr_accessor :template, :edittemplate, :do_images
	def initialize(req)
		super
		if File.exists?(File.join(docroot, '.ambindextrous.html'))
			templatefile = File.join(docroot, '.ambindextrous.html')
		elsif File.exists?(File.join(docroot, 'ambindextrous.html'))
			templatefile = File.join(docroot, 'ambindextrous.html')
		else
			templatefile = File.join(File.dirname(__FILE__), 'ambindextrous.html')
		end
		self.template = XMLTemplateFile.new(templatefile)
		if File.exists?(File.join(docroot, 'ambindextrous-edit.html'))
			self.edittemplate = XMLTemplateFile.new(File.join(docroot, 'ambindextrous-edit.html'))
		else
			self.edittemplate = XMLTemplateFile.new('ambindextrous-edit.html')
		end
		self.do_images = if File.read(templatefile).grep(/amrita:id=.images./): true  else false end
	end

	def run
		if(mode == 'POST')
			save_feedback
		else
			out << "Content-type: text/html\n\n"
			if(query == 'edit-feedback')
				show_edit
			else
				show_listing
			end
		end
	end

	def save_feedback
		param_data = self.in.read(self.in.size)
		param_data = param_data.split('&').map {|e| e.split('=')}
		params = Hash.new { |h,k| h[k] = param_data.assoc(k)[1] }
		if params['text']
			File.set_attr(systempath, 'feedback', params['text'].formdecode)
		end
		out << "Status: 302\nLocation: #{path}\n\n"
	end

	def show_edit
		begin
			data = { :text => File.get_attr(systempath, 'feedback') , :path => path }
		rescue Errno::EOPNOTSUPP => e
			data = { :text => '', :path => path }
		end
		edittemplate.expand out, data
	end

	def show_listing
		data = Hash.new
		data[:path] = path
		data[:images] = []
		data[:entries] = []

		begin
			a = File.get_attr systempath, 'feedback'
		rescue Errno::EOPNOTSUPP => e
			a = ''
		end

		data[:feedback] = Amrita::SanitizedString.new(a.gsub("(.*)\n", '<p>\1</p>')) if a
		begin
			a = File.get_attr systempath, 'description'
		rescue Errno::EOPNOTSUPP => e
			a = ''
		end
		data[:description] = Amrita::SanitizedString.new(a.gsub("\n", "<br />")) if a
		Dir.open(systempath).each do |e|
			begin 

				next if !File.readable? File.join(systempath, e)
				next if e[0] == ?.
				
				s = File.stat(qp = File.join(systempath, e))
				extension = ''

				if match = /([.][a-z0-9]+)$/i.match(e)
					$stderr.puts "Chopping extension from #{e}"
					if ['html', 'png', 'jpg', 'gif', 'swf', 'mp3', 'ogg'].include? match[1]
						extension = match[1]
						e = e[(0..(-extension.length - 1))]
					end
				end

				entry = {
					:pathurl => Amrita::SanitizedString.new(e.urlencode),
					:path => e, 
					:extension => extension,
					:description => (File.get_attr(qp, 'description') rescue ''), 
					:type => if s.directory? then '/' else '' end, 
					:time => s.mtime.strftime('%e %b %y'), 
					:size => File.contentsize(qp)
				} 
				if /[.](jpg|gif|png|svg)/ =~ e
					entry[:thumbnail] = '?thumbnail=' + e.urlencode
					data[:images] << entry
				else
					data[:entries] << entry
				end
			rescue Exception => x
				LOGGER.debug x
			end
		end
		if !do_images 
			data[:entries] += data[:images]
		end
		data[:images].sort! { |x,y| x[:path] <=> y[:path] }
		data[:entries].sort! { |x,y| x[:path] <=> y[:path] }
		LOGGER.debug { data[:images].inspect }
		template.expand out, data
	end
end

class Cacher
	attr_accessor :cachedir
	def initialize(dirs)
		self.cachedir = dirs.find { |d| 
			begin
				d if (File.writable?(d) and File.directory?(d)) or FileUtils.mkdir_p(d)
			rescue Errno::EACCES
				false
			end
		}
		if !cachedir 
			raise "Cannot create cache dir"
		end
	end
	def cached(file)
		c = mangle(file)
		if File.exist? c and File.stat(c).mtime >= File.stat(file).mtime
			return File.read(c)
		else
			content = yield(file)
			File.open(c, 'w') { |f| f.puts(content) }
			return content
		end
	end
	def mangle(filename)
		md5 = Digest::MD5.new(filename).to_s
		File.join(cachedir, md5)
	end
end

class FreedesktopThumbnailCacher < Cacher
	def mangle(filename)
		super('file://' + filename) + '.png'
	end
end

class Thumbnailer < FCGILet
	CacheDirs = [File.join(ENV['HOME'], '.thumbnails/tiny'), '/tmp/thumbnails/tiny']
	attr_accessor :size
	attr_accessor :format
	def initialize(fcgi, size)
		self.size = size
		self.format = 'PNG'
		super(fcgi)
	end

	def run(image)
		cacher = FreedesktopThumbnailCacher.new(CacheDirs)
		file = File.join(systempath, image)
		content = cacher.cached(file) do
			img = Magick::Image.read(file).first
			img.change_geometry!(size) { |cols, rows| img.thumbnail! cols, rows }
			img.format = format.upcase
			img.to_blob
		end
		out << "Content-type: image/#{format.downcase}\n"
		out << "Content-Length: #{content.size}\n\n" 
		out << content
	end
end

FCGI.each do |fcgi|
	begin
		if /thumbnail=(.*)/ =~ fcgi.env['QUERY_STRING']
			Thumbnailer.new(fcgi, '32x24').run($1)
		elsif /size=(.*)&resize=(.*)/ =~ fcgi.env['QUERY_STRING']
			Thumbnailer.new(fcgi, $1).run($2)
		else
			Ambindextrous.new(fcgi).run
		end
	rescue
		fcgi.out << "Status: 500\n"
		fcgi.out << "Content-Length: 0\n\n"
	end
	fcgi.finish
end
	
# vim: syntax=ruby
