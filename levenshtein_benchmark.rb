require 'benchmark'
require 'levenshtein'

include Levenshtein


str1 = "This is a very close string"
str2 = "This is not a very close string"
str3 = "Cows don't fly over restricted air space"


Benchmark.bmbm(30) do |bm|
  bm.report("distance_ruby") do
    1000.times do
      distance_ruby(str1, str1)
      distance_ruby(str1, str2)
      distance_ruby(str1, str3)
      distance_ruby(str2, str1)
      distance_ruby(str2, str2)
      distance_ruby(str2, str3)
      distance_ruby(str3, str1)
      distance_ruby(str3, str2)
      distance_ruby(str3, str3)
    end
  end
end

if inline_c_available
  puts
  Benchmark.bmbm(30) do |bm|
    bm.report("distance_c") do
      1000.times do
        distance_c(str1, str1)
        distance_c(str1, str2)
        distance_c(str1, str3)
        distance_c(str2, str1)
        distance_c(str2, str2)
        distance_c(str2, str3)
        distance_c(str3, str1)
        distance_c(str3, str2)
        distance_c(str3, str3)
      end
    end
  end
end

if inline_java_available
  puts
  Benchmark.bmbm(30) do |bm|
    bm.report("distance_java") do
      1000.times do
        distance_java(str1, str1)
        distance_java(str1, str2)
        distance_java(str1, str3)
        distance_java(str2, str1)
        distance_java(str2, str2)
        distance_java(str2, str3)
        distance_java(str3, str1)
        distance_java(str3, str2)
        distance_java(str3, str3)
      end
    end
  end
end
