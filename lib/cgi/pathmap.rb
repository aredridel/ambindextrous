require 'uri'
require 'etc'

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


module WebDevHelper
	def docroot
		docroot = env['DOCUMENT_ROOT']
		if(env['QUERY_STRING'].empty?)
			path = env['REQUEST_URI'].urldecode
		else
			path = env['REQUEST_URI'].split('?')[0].urldecode
		end
		if path =~ %r{/~([^/]+)}
			docroot = File.join(Etc.getpwnam($1).dir, (if selfurl.host =~ /evil/: 'evil' else 'web' end))
		end
		docroot
	end

	def path_translated(path = nil)
		if path.nil?
			path = selfurl.path
		end
		path = path.gsub  %r{^/~([^/])+/}, '/'
		File.join(docroot, path)
	end

	def selfurl
		URI.selfurl(self)
	end
end

class CGI
	def env
		::ENV
	end

	include WebDevHelper
end

module URI
	def self.selfurl(req)
		URI.parse("http#{req.env['HTTPS'] and req.env['HTTPS'].downcase == 'on' ? 's' : ''}://#{req.env['HTTP_HOST']}#{req.env['SERVER_PORT'] != '80' ? ":" + req.env['SERVER_PORT'] : ''}#{req.env['REQUEST_URI']}")
	end
end

class FCGI
	include WebDevHelper
end
