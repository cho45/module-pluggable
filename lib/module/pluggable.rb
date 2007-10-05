# Author::    cho45 <cho45@lowreal.net>
# Copyright:: copyright (c) 2007 cho45 www.lowreal.net
# License::   Ruby's

require "pathname"

module Module::Pluggable
	DEFAULT_OPTS = {
		:search_path => "plugins",
		:except      => /_$/,
		:base_class  => nil,
	}.freeze

	# pluggable make the name of instance method
	# returning instance of Module::Pluggable::Plugin.
	#
	# All loaded plugins are in anonymous module,
	# so you can't access the classes directly,
	# and you can create some plugin-sets
	# without confusing class variables etc.
	# 
	#     opts => {
	#         :search_path => name,
	#         :base_class => nil,
	#         :except => /_$/, # not yet
	#     }
	def pluggable(name=:plugins, o={})
		opts = DEFAULT_OPTS.merge(o)
		opts[:search_path] = name ? name.to_s : opts[:name].to_s unless opts[:search_path]

		class_eval <<-EOS
			def #{name}
				@#{name} ||= Module::Pluggable::Plugins.new(@@pluggable_opts[:#{name}])
			end

			def self.set_pluggable_opts(name, opts)
				(@@pluggable_opts ||= {})[name] = opts
			end
		EOS
		self.set_pluggable_opts(name, opts)
		(class << self; self; end).instance_eval do
			remove_method(:set_pluggable_opts)
		end
	end

	class Plugins
		include Enumerable

		class PluginsError < StandardError; end
		class ClassNotFoundError < PluginsError; end
		class NotInheritAbstractClassError < PluginsError; end

		def initialize(opts)
			@opts  = opts
			@dir   = Pathname.new(opts[:search_path])
			@plugins = {}
			reload
		end

		# Load +klass_name+.
		# The plugin is loaded in anonymous module not order to
		# destroy the environments.
		# And remember loaded time for reloading.
		#
		# plugin filename must be interconversion with its class name.
		# In this class, the conversion is do with +file2klass+/+klass2file+ methods.
		def load(klass_name)
			return if @plugins.include?(klass_name)
			
			filename = klass2file(klass_name)
			
			mod = Module.new
			mod.module_eval(File.open("#{@opts[:search_path]}/#{filename}.rb") {|f| f.read}, filename)
			
			c = nil
			begin
				c = mod.const_get(klass_name)
			rescue NameError
				raise ClassNotFoundError.new("#{@opts[:search_path]}/#{filename} must include #{klass_name} class")
			end
			
			if !@opts[:base_class] || c < @opts[:base_class]
				@plugins[klass_name] = {
					:instance => c.new,
					:loaded   => Time.now,
				}
			else
				raise NotInheritAbstractClassError.new("The class #{klass_name} must inherit #{@opts[:base_class]}")
			end

			@plugins[klass_name][:instance].on_load rescue NameError
			@plugins[klass_name][:instance].instance_variable_set(:@plugins, self)
			
			klass_name
		end

		# Get instance of +klass_name+ plugin.
		def [](klass_name)
			@plugins[klass_name][:instance] if @plugins.key?(klass_name)
		end
		
		# Unload +klass_name
		def unload(klass_name)
			if @plugins.key?(klass_name)
				@plugins[klass_name][:instance].on_unload rescue NameError
				@plugins.delete(klass_name)
			end
		end
		
		# Reload +klass_name+ or
		# load unloaded plugins or
		# reload modified plugins.
		# returns [loaded, unloaded]
		def reload(klass_name=nil)
			if klass_name
				unload(klass_name)
				load(klass_name)
				klass_name
			else
				loaded   = []
				unloaded = []
				Dir.glob("#{@opts[:search_path]}/*.rb") do |f|
					klass_name = file2klass(File.basename(f, ".rb").sub(/^\d+/, ""))
					if @plugins.include?(klass_name)
						if File.mtime(f) > @plugins[klass_name][:loaded]
							loaded << reload(klass_name)
						end
					else
						loaded << reload(klass_name)
					end
				end
				[loaded, unloaded]
			end
		end
		
		# Unload all plugins and reload it.
		def force_reload
			call(:on_unload)
			@plugins.clear
			reload
		end
		
		# Iterates with plugin name and its instance.
		def each(&block)
			@plugins.each do |k,v|
				yield k, v[:instance]
			end
		end
		
		# Call +name+ method of each plugins with +args+
		# and returns Hash of the result and its plugin name.
		def call(name, *args)
			ret = {}
			each do |k,v|
				ret[k] = v.send(name, *args) if v.respond_to?(name)
			end
			ret
		end

		# Undefined methods are delegated to each plugins.
		# This is alias of +call+
		def method_missing(name, *args)
			call(name, *args)
		end

		private
		# convert foo/foo_bar to Foo::FooBar
		def file2klass(str)
			str.split("/").map {|c|
				c.split(/_/).collect {|i| i.capitalize }.join("")
			}.join("::")
		end
		
		# convert Foo::FooBar to foo/foo_bar 
		def klass2file(str)
			str.split(/::/).map {|c|
				c.scan(/[A-Z][a-z0-9]*/).join("_").downcase
			}.join("/")
		end
	end
end
Class.instance_eval { include Module::Pluggable }
