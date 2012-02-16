require "test/unit"
require 'levenshtein'

class LevenshteinTest < Test::Unit::TestCase
  
  include Levenshtein

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # verify that results of distance_c() match distance_ruby()
  def test_distance_c
    if inline_c_available
      str1 = "This is a very close string"
      str2 = "This is not a very close string"
      str3 = "Cows don't fly over restricted air space"
      assert_equal(distance_ruby(str1, str1), distance_c(str1, str1))
      assert_equal(distance_ruby(str1, str2), distance_c(str1, str2))
      assert_equal(distance_ruby(str1, str3), distance_c(str1, str3))
      assert_equal(distance_ruby(str2, str1), distance_c(str2, str1))
      assert_equal(distance_ruby(str2, str2), distance_c(str2, str2))
      assert_equal(distance_ruby(str2, str3), distance_c(str2, str3))
      assert_equal(distance_ruby(str3, str1), distance_c(str3, str1))
      assert_equal(distance_ruby(str3, str2), distance_c(str3, str2))
      assert_equal(distance_ruby(str3, str3), distance_c(str3, str3))
    else
      puts "NOTE: skipped test_distance_c because inline C not available"
    end
  end
  
  # verify that results of distance_java() match distance_ruby()
  def test_distance_java
    if inline_java_available
      str1 = "This is a very close string"
      str2 = "This is not a very close string"
      str3 = "Cows don't fly over restricted air space"
      assert_equal(distance_ruby(str1, str1), distance_java(str1, str1))
      assert_equal(distance_ruby(str1, str2), distance_java(str1, str2))
      assert_equal(distance_ruby(str1, str3), distance_java(str1, str3))
      assert_equal(distance_ruby(str2, str1), distance_java(str2, str1))
      assert_equal(distance_ruby(str2, str2), distance_java(str2, str2))
      assert_equal(distance_ruby(str2, str3), distance_java(str2, str3))
      assert_equal(distance_ruby(str3, str1), distance_java(str3, str1))
      assert_equal(distance_ruby(str3, str2), distance_java(str3, str2))
      assert_equal(distance_ruby(str3, str3), distance_java(str3, str3))
    else
      puts "NOTE: skipped test_distance_java because inline java not available"
    end
  end
  
end