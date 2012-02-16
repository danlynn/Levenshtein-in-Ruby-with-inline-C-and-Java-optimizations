# demonstrate inline-C code: defining a class method in C

require 'rubygems'
require 'inline'

class RubyInline
	class << self
		begin
			inline :C do |builder|
				builder.c '
					int foo3() {
						return 5;
					}
				'
			end
		rescue Exception => e
			puts "RubyInline failed to compile inline C: #{e}"
		end
	end
end

puts RubyInline.foo3
