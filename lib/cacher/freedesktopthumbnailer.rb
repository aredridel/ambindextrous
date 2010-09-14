require 'cacher'
require 'RMagick'

class FreedesktopThumbnailer < Cacher
	SIZES = {
		'normal' => '128x128',
		'large' => '256x256',
		'tiny' => '32x24'
	}

	SIZE_NAMES = SIZES.invert

	attr_accessor :size, :sizename
	CacheDirs = ['/var/cache/thumbnailer', File.join(ENV['HOME'], '.thumbnails'), '/tmp/thumbnails']
	def initialize(size)
		if !/x/.match(size)
			size = SIZES[size]
		end
		self.size = size
		self.sizename = SIZE_NAMES[size] || size
		super(CacheDirs)
		FileUtils.mkdir_p(cachedir)
	end

	def mangle(filename)
		super('file://' + filename) + '.png'
	end

	def cachedir
		File.join(super, sizename) 
	end

	def thumbnail(file, format)
		cached(file) do
			img = Magick::Image.read(file).first
			img.change_geometry!(size) { |cols, rows| img.thumbnail! cols, rows }
			img.format = format.upcase
			img.to_blob
		end
	end
end
