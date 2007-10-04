require File.dirname(__FILE__) + '/test_helper.rb'
require "pathname"
require "tmpdir"
require "fileutils"

class TestModulePluggable < Test::Unit::TestCase
	def setup
		@dir = Pathname.new(Dir.tmpdir) + "#{File.basename($0)}.#$$.#{rand(0xffffff)}"
		@dir.mkpath
		@test_dir = Pathname.new(File.dirname(__FILE__))
		FileUtils.cp_r(@test_dir + "plugins", @dir)
		@plugins_dir = @dir + "plugins"
	end

	def teardown
		@dir.rmtree
	end

	def test_classname_conversion
		m = Module::Pluggable::Plugins.new({:search_path => @plugins_dir})
		assert_equal "foo_bar",     m.__send__(:klass2file, "FooBar")
		assert_equal "FooBar",      m.__send__(:file2klass, "foo_bar")
		assert_equal "foo/foo_bar", m.__send__(:klass2file, "Foo::FooBar")
		assert_equal "Foo::FooBar", m.__send__(:file2klass, "foo/foo_bar")
	end

	def test_success
		path = @plugins_dir
		test = Class.new {
			pluggable :plugins, :search_path => path
		}.new
		assert test.plugins["Test"]
		assert_equal "This is test plugin.", test.plugins.call(:description)["Test"]

		obj = Object.new
		test.plugins.call(:instance_variable_set, :@test_obj, obj)
		assert_equal obj, test.plugins["Test"].instance_variable_get(:@test_obj)
		assert_equal test.plugins, test.plugins["Test"].foobar

		assert_equal "This is test plugin.", test.plugins.description["Test"]

		test = Class.new {
			pluggable :plugins, :search_path => "'"
		}.new
	end

	def test_multi
		path = @plugins_dir
		test = Class.new {
			pluggable :plugins, :search_path => path
			pluggable :filters, :search_path => path
		}.new
		assert test.plugins["Test"]
		assert_equal "This is test plugin.", test.plugins.call(:description)["Test"]
		assert test.filters["Test"]
		assert_equal "This is test plugin.", test.filters.call(:description)["Test"]
	end

	def test_inherit
		path = @plugins_dir
		assert_raise(Module::Pluggable::Plugins::NotInheritAbstractClassError) do
			test = Class.new {
				pluggable :plugins, :search_path => path, :base_class => PluginBase
			}.new
			test.plugins
		end

		testpl = path + "test.rb"
		n = testpl.read.sub(/class Test/, "class Test < TestModulePluggable::PluginBase")
		testpl.open("w") {|f| f.puts n }

		assert_nothing_raised do
			test = Class.new {
				pluggable :plugins, :search_path => path, :base_class => PluginBase
			}.new
			test.plugins
		end
	end

	class PluginBase
		# Nice boat.
	end
end
