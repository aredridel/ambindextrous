require 'fileutils'
require 'digest/md5'

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
		md5 = Digest::MD5.hexdigest(filename)
		File.join(cachedir, md5)
	end
end
