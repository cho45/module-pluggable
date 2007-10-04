#!ruby -I../lib simple.rb

require "module/pluggable"

class SimplePluggable
	# pluggable [name=:plugins] [opts]
	# pluggable make the name of instance method
	# returning instance of Module::Pluggable::Plugin.
	#
	# All loaded plugins are in anonymous module,
	# so you can't access the classes directly,
	# and you can create some plugin-sets
	# without confusing class variables etc.
	pluggable

	def initialize
		# `init' method is not defined on Module::Pluggable::Plugin.
		# undefined methods are delegated to `call' the plugins.
		# In this case, `plugins.init(self)' is same as `plugins.call(:init, self)'.
		plugins.init(self)
	end

	def say
		plugins.each do |name, instance|
			puts instance.say
		end
	end
end

SimplePluggable.new.say
