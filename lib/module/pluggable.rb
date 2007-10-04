
#require "module/pluggable"

require "pathname"

module Module::Pluggable
	DEFAULT_OPTS = {
		:search_path => "plugins",
		:except      => /_$/,
		:base_class  => nil,
	}.freeze

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

		def [](klass_name)
			@plugins[klass_name][:instance] if @plugins.key?(klass_name)
		end
		
		def unload(klass_name)
			if @plugins.key?(klass_name)
				@plugins[klass_name][:instance].on_unload rescue NameError
				@plugins.delete(klass_name)
			end
		end
		
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
		
		def force_reload
			call(:on_unload)
			@plugins.clear
			reload
		end
		
		def each(&block)
			@plugins.each do |k,v|
				yield k, v[:instance]
			end
		end
		
		def call(name, *args)
			ret = {}
			each do |k,v|
				ret[k] = v.send(name, *args) if v.respond_to?(name)
			end
			ret
		end

		def method_missing(name, *args)
			call(name, *args)
		end

		# foo/foo_bar => Foo::FooBar
		def file2klass(str)
			str.split("/").map {|c|
				c.split(/_/).collect {|i| i.capitalize }.join("")
			}.join("::")
		end
		
		# Foo::FooBar => foo/foo_bar 
		def klass2file(str)
			str.split(/::/).map {|c|
				c.scan(/[A-Z][a-z0-9]*/).join("_").downcase
			}.join("/")
		end
	end
end
Class.instance_eval { include Module::Pluggable }
