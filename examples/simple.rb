#!ruby -I../lib simple.rb

require "module/pluggable"

class SimplePluggable
	pluggable

	def initialize
		plugins.init(self)
	end

	def say
		plugins.each do |name, instance|
			puts instance.say
		end
	end
end

SimplePluggable.new.say
