# demonstrate inline-Java code: Simplest hello world script (no ruby class)

require 'fileutils'
require 'rubygems'
require 'inline'

unless File.exists?(Inline.directory)
	FileUtils.mkdir_p(Inline.directory)
end

require 'java_inline'

class << self
	inline :Java do |builder|
		builder.java '
			public static void foo() {
				System.out.println("hello world!");
			}
		'
	end
end

foo
