# demonstrate inline-C code: Simplest hello world script (no ruby class)

require 'rubygems'
require 'inline'

class << self
	inline :C do |builder|
		builder.c '
			void foo() {
				printf("hello world!\n");
			}
		'
	end
end

foo
