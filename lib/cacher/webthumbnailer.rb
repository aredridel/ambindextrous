require 'cacher'
require 'epeg'
require 'rmagick'

class WebThumbnailer < Cacher
	SIZES = {
		'normal' => '128x128',
		'large' => '256x256',
		'tiny' => '32x24'
	}

	SIZE_NAMES = SIZES.invert

	attr_accessor :x, :y, :sizename
	CacheDirs = ['/var/cache/thumbnailer', File.join(ENV['HOME'] || '/tmp', '.thumbnails'), '/tmp/thumbnails']
	def initialize(size)
		if !/x/.match(size)
			size = SIZES[size]
		end
		self.x, self.y = size.split('x').map { |e| e.to_i }
		self.sizename = SIZE_NAMES[size] || size
		super(CacheDirs)
		FileUtils.mkdir_p(cachedir)
	end

	def mangle(filename)
		super('file://' + filename) + '.jpg'
	end

	def cachedir
		File.join(super, sizename) 
	end

	def thumbnail(file)
		cached(file) do
			jpeg = File.open(file) do |f|
				f.read(4) == 'JFIF'
			end
			if jpeg	
				e = Epeg.new(file)
				ox,oy = e.size
				scale = [1.0 / [(ox / x), 1].max, 1.0 / [(oy / y), 1].max].min
				dx = (ox * scale).floor
				dy = (oy * scale).floor
				e.set_output_size(dx,dy)
				e.finish
			else
				img = Magick::Image.read(file).first
				img.change_geometry!("#{x}x#{y}") { |cols, rows| img.thumbnail! cols, rows }
				img.format = 'JPEG'
				img.to_blob
			end
		end
	end
end
