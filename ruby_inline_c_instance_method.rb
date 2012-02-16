# demonstrate inline-C code: defining an instance method in C

require 'rubygems'
require 'inline'

class RubyInline
	begin
		inline :C do |builder|
			builder.c '
				int foo2() {
					return 5;
				}
			'
		end
	rescue Exception => e
		puts "RubyInline failed to compile inline C: #{e}"
	end
end

puts RubyInline.new.foo2
