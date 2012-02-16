### Levenshtein String Distance for Ruby

See my blog post regarding this code at: <http://danlynn.org/home/2012/1/15/ruby-optimized-using-inline-c-and-java.html>

A while back, for the pure joy of programming, I spent the weekend updating my Levenshtein module with inline Java and C language optimizations.  The Levenshtein string distance algorithm is a great way to determine how similar two strings are to each other.  However, it is very CPU intensive.  Therefore, I added Java and C versions of the core algorithm which produce 60x and 500x improvements in performance over the pure ruby implementation.

The optimizations will be wrapped in some code that determines the environment in which the code is being executed and automatically select the appropriate optimization.  If for any reason the optimizations fail to execute then the module will automatically fail back to the pure ruby version of the core algorithm.

I was compelled to implemented these optimizations in order to speed up one of the aspects of my log analysis project.  It examines the logs from a set of 48 servers and categorizes and organizes the error messages into reports.  An important part of this is identifying error messages which are actually duplicates of each other but only vary by something like a UserID or object ID occuring in the message text.  I used the Levenshtein string distance algorithm to help determine this.  Crunching this much data in ruby proved to be very time-consuming.  Imagine how delighted I was when I realized a 500x improvement in performance by optimizing this algorithm using the C programming language! 

Since some of the deployments of my log analysis software are in a JRuby environment, I spent some extra time figuring out if inline C worked in JRuby.  It turns out that at this time, there is a bug in the RubyInline gem that prevents inline C from working.  Thus, I managed to find the java_inline gem which extends the RubyInline framework to provide inline Java.  It turns out that even Java code executes 60x faster than ruby.

I will provide test code and benchmark performance results that show how beneficial a little inline Java or C can be.

### Dependencies

If running with the native ruby interpreter (Matz) then you will need to install the RubyInline gem:

```console
$ gem install RubyInline
```

If running with JRuby then you will need to install both the RubyInline and the java_inline gems:

```console
$ gem install RubyInline $ gem install java_inline
```

In order to use the inline C code, you will need to have a C compiler installed on your machine.

If on MacOS X then just install Xcode tools from the AppStore:

	<http://itunes.apple.com/us/app/xcode/id448457090?mt=12>

If on Windows then try following these instructions:

	<http://thewebfellas.com/blog/2007/12/2/imagescience-and-rubyinline-on-windows>

If on linux, just verify that you have gcc installed (also works to verify Xcode is installed on OSX):

```console
gcc -v
```

In order to use inline Java code, you will need to be running your ruby code using JRuby and have the Java SE JDK installed (version 1.6 or higher).  Make sure you click on the JDK download instead of the JRE download so that you will be able to compile java code:

	<http://www.oracle.com/technetwork/java/javase/downloads/index.html>

###Simple Code Example

Let's do the most basic Hello World example using inline C.  The way that RubyInline works, you must define your C (or Java, etc.) code as functions.  Therefore, we can't simply put the line

```ruby
printf("hello world!\n");
```

within the inline block.  Instead we have to wrap it inside a C style function call like

```ruby
void foo() {
    printf("hello world!\n");
}
```

Then you may call the function foo() from anywhere within your code.  The the following minimalist example, we call foo on the last line of the script after first defining the inline C function.

```ruby
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
```

Note how everything is wrapped within a class block (class << self). This is because the RubyInline gem needs to have a class to attach the C function to. Wrapping it like this provides that context. Also, I chose to use single quotes across multiple lines instead of double quotes or a "here-doc" style <<-EOS string to pass the string literal containing the C source code because it allowed me to avoid escaping any characters within the C source.

In most cases, your use of RubyInline won't be quite this simple.  You will most likely be adding instance or class methods to an actual ruby class.  Also, you should provide some error handling in case they are missing a C compiler or there is an error in the actual C source code.  The following two examples demonstrate these features.  Notice how the method is called in the last line of each code example.

Adding a C function as an instance method to a ruby class:

```ruby
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
```

Adding a C function as a class method to a ruby class.  Note the wrapping of the inline code within a 'class << self' block - see lines 5 and 17:

```ruby
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
```

###Sophisticated Code Example

Now we're going to get back to my actual implementation of the Levenshtein string distance algorithm with both inline C and Java optimizatized versions.  This example has extensive error handling and automated fail-over features.  For example, if you are missing any of the gems supporting inlining then a message will be emitted to the console suggesting that you install the missing gems and notifying you that it is failing back to using the pure ruby version of the algorithm.  The gem availability checks occur only once - when the class is loaded.

The inline C or Java methods are compiled only once upon class loading.  If any failures occur due to missing C or Java compiler or a syntax error in the inline code then a helpful error is displayed in the console and the class automatically fails back to using the pure ruby version of the algorithm.

I chose to implement this code in a module so that it could be mixed into the actual reporting classes.  I anticipate abstracting the automatic loading and fail-over functionality of this module to be mixed into classes which define their own inline C or Java methods.  Thus, implementing as a module to be mixed in via the include statement made a lot of sense.

The following is the actual source of the Levenshtein module being used in my log analysis software.  After the listing, I will point out some of the features called out by line numbers.

```ruby
# Module provides Levenshtien string distance method that attempts to use an 
# optimized inline-C or inline-Java version of the algorithm if the RubyInline 
# and/or inline-java gems are available.
# 
# Be sure to first install the RubyInline gem with:
#
#   gem install RubyInline
#
# If running under JRuby then ALSO install the inline-java gem with:
# 
#   gem install java_inline
#
# If RubyInline is not available or if it fails to compile the inline-C code for
# some reason (like running on Windoze with no C compiler installed) then it 
# will fail back to a pure ruby implementation of the algorithm.  If you want
# to try to get it working on Windoze then check out:
# http://thewebfellas.com/blog/2007/12/2/imagescience-and-rubyinline-on-windows
#
# If running under JRuby and RubyInline or java_inline is not available or if it
# fails to compile the inline-java code (like if JDK 1.6 is not available) then
# it will fail back to a pure ruby implementation of the algorithm.
#
# Note that JRuby currently does not work with inline-C code (due to recent 
# defect).  Therefore, the inline-C optimization will only be used under the
# native ruby interpreter.  Also the inline-Java code only works when running 
# under JRuby.
# 
# If an optimization is not available under your current environment then a 
# message will be emitted when the module is loaded requesting that the 
# appropriate gems be installed.  However, the code will continue to run just
# fine failing back to the pure ruby implementation.
module Levenshtein

  @@inline_available = nil
  @@inline_c_available = nil
  @@inline_java_available = nil
  
  begin
    require 'rubygems'
    @@inline_c_available = @@inline_available = (require 'inline')
    if RUBY_PLATFORM =~ /java/i
      unless File.exists?(Inline.directory)
        require 'fileutils'
        FileUtils.mkdir_p(Inline.directory)
      end
      begin
        @@inline_java_available = require 'java_inline'
      rescue
        puts "    NOTE: java_inline gem not installed - failing back to pure ruby levenshtein"
        puts "    Install the java_inline gem in order to improve performance by 90x. This "
        puts "    will activate an inline-Java optimization."
      end
    end
  rescue Exception
    puts "    NOTE: RubyInline gem not installed - failing back to pure ruby levenshtein"
    if RUBY_PLATFORM =~ /java/i
      puts "    Install both the RubyInline and java_inline gems in order to improve performance "
      puts "    by 90x. This will activate an inline-Java optimization."
    else
      puts "    Install the RubyInline gem in order to improve performance by 500x. This will "
      puts "    activate an inline-C optimization."
    end
  end

  
  # returns nil if distance_java() method is not available
  def inline_java_available
    @@inline_java_available
  end


  # returns nil if distance_c() method is not available
  def inline_c_available
    @@inline_c_available
  end
  
  
  # Perform a Levenshtein string distance calculation to determine how 
  # similar 'str1' and 'str2' are to each other.  Note that this method 
  # automagically uses the inline-C or inline-Java optimized algorithms if 
  # available.  The return value represents how similarity - the smaller the
  # number the closer the two strings are to each other.  The return value 
  # actually shows the number of inserts, deletes, and changes that would need 
  # to be made on a character by character basis to change 'str1' into 'str2'.
  def distance(str1, str2)
    if @@inline_c_available
      return distance_c(str1, str2)
    elsif @@inline_java_available
      return distance_java(str1, str2)
    else
      return distance_ruby(str1, str2)
    end
  end


  # inline-c implementation of Levenshtein string distance - note that this 
  # version uses a slightly different, more memory intensive algorithm than the
  # pure-ruby and pure-java versions.
  if @@inline_c_available
    if RUBY_PLATFORM =~ /java/i  # JRuby fails and exits on inline-C at the moment
      @@inline_c_available = nil
    else
      begin
        inline :C do |builder|
          builder.include '<stdlib.h>'
          builder.include '<string.h>'
          builder.c "
              static int distance_c(char* s, char* t)
              /*Compute levenshtein distance between s and t*/
              {
                //Step 1
                int min, k,i,j,n,m,cost,*d,distance;
                n=strlen(s);
                m=strlen(t);
                if (n==0) return m;
                if (m==0) return n;
                d=malloc((sizeof(int))*(m+1)*(n+1));
                m++;
                n++;
                //Step 2
                for(k=0;k<n;k++)
                {
                  d[k]=k;
                }
                for(k=0;k<m;k++)
                {
                  d[k*n]=k;
                }
                //Step 3 and 4
                for(i=1;i<n;i++)
                {
                  for(j=1;j<m;j++)
                  {
                    //Step 5
                    if(s[i-1]==t[j-1])
                    {
                      cost=0;
                    } else {
                      cost=1;
                    }
                    //Step 6
                    min = d[(j-1)*n+i]+1;
                    if (d[j*n+i-1]+1 < min) min=d[j*n+i-1]+1;
                    if (d[(j-1)*n+i-1]+cost < min) min=d[(j-1)*n+i-1]+cost;
                    d[j*n+i]=min;
                  }
                }
                distance=d[n*m-1];
                free(d);
                return distance;
              }
              "
        end
      rescue Exception => e
        puts "    Note RubyInline failed to compile inline C - failing back to pure ruby levenshtein: #{e}"
        @@inline_c_available = nil
      end
    end
  end
  
  
  # inline-java implementation of Levenshtein string distance - note that this
  # algorithm is identical to the pure-ruby algorithm.
  if @@inline_java_available
    begin
      inline :Java do |builder|
        builder.package "org.danlynn"
        builder.java "
            public static int distance_java(String str1, String str2) {
                byte[] s = str1.getBytes();
                byte[] t = str2.getBytes();
                int n = s.length;
                int m = t.length;
            
                if (n == 0)
                    return m;
                if (m == 0)
                    return n;
            
                int i = 0;
                int j = 0;
            
                int[] d = new int[m + 1];
                for (i = 0; i <= m; ++i)
                    d[i] = i;
            
                int x = 0;
                int e = 0;
                int cost = 0;
                int ins = 0;
                int del = 0;
                int sub = 0;
            
                for (i = 0; i < n; ++i) {
                    e = i + 1;
                    for (j = 0; j < m; ++j) {
                        cost = (s[i] == t[j] ? 0 : 1);
                        ins = d[j + 1] + 1;
                        del = e + 1;
                        sub = d[j] + cost;
                        x = del < sub ? del : sub;
                        x = ins < x ? ins : x;
                        d[j] = e;
                        e = x;
                    }
                    d[m] = x;
                }
                return x;
            }
            "
      end
    rescue Exception => e
      puts "    Note RubyInline failed to compile inline Java - failing back to pure ruby levenshtein: #{e}"
      @@inline_java_available = nil
    end
  end
  

  # helper method used by distance_ruby() to determine string encodings
  def encoding_of(string)
    if RUBY_VERSION[0, 3] == "1.9"
      string.encoding.to_s
    else
      $KCODE
    end
  end


  # perform a pure-ruby Levenshtein string distance calculation to determine how 
  # similar 'str1' and 'str2' are to each other
  def distance_ruby(str1, str2)
    encoding = defined?(Encoding) ? str1.encoding.to_s : $KCODE

    if encoding_of(str1) =~ /^U/i
      unpack_rule = 'U*'
    else
      unpack_rule = 'C*'
    end

    s = str1.unpack(unpack_rule)
    t = str2.unpack(unpack_rule)
    n = s.length
    m = t.length

    return m if (0 == n)
    return n if (0 == m)

    d = (0..m).to_a
    x = nil
    s_i = nil

    (0...n).each do |i|
      e = i+1
      s_i = s.at(i)
      (0...m).each do |j|
        cost = (s_i == t.at(j)) ? 0 : 1
        x = [
          d.at(j+1) + 1, # insertion
          e + 1,         # deletion
          d.at(j) + cost # substitution
        ].min
        d[j] = e
        e = x
      end
      d[m] = x
    end

    return x
  end

end
```

Lines 38..63 determine which inlining gems are available and print helpful instructions to the console suggesting which gems should be installed in order to obtain performance improvements.

Lines 42..45 compensate for a bug in the java_inline gem where the cache directory fails to be created. This compensating code will automatically create the cache directory if missing.  I've submitted a patch to the java_inline gem (part of the JRuby project) that corrects this problem.

Lines 78..93 define the actual distance() method that will be called externally.  This method checks whether either of the inline optimizations are available and calls them.  If neither optimization is available then it simply calls the pure ruby distance_ruby() method.

Lines 96..159 attempt to define the C function distance_c() as an instance method in the Levenshtein module.  Note that this code executes at the time the module is actually loaded.  If any failure occurs due to a syntax error in the C source code or because no C compiler can be found then the class variable @@inline_c_available is set back to nil marking the distance_c() method as being unavailable.

Lines 162..216 attempt to define the Java method distance_java() as an instance method in the Levenshtein module.  The same types of fail-over mechanisms used in the inline C version are also used here.

Lines 219..269 define the pure ruby implemenation of the distance algorithm.

###Benchmarking Inline Code Performance

To demonstrate how incredible the performance improvements can be by using inline C and Java, I've worked up a script to perform some benchmarking.  This script times how long it takes to calculate 9 Levenshtein string distances (permutation of distances between 3 strings and themselves).  These 9 calculations are performed 1000 times in order to provide a managable sampling time.

The script first performs this benchmark using the pure ruby version of the algorithm.  Note that we call the distance_ruby(), distance_c(), and distance_java() methods directly rather than the main distance() method because the main method always choses the most optimized version of the algorithm based on the current execution environment.

Next, either the inline C or the inline Java version of the algorithm is benchmarked depending upon whether or not you are running in the native (Matz) ruby interpreter or within JRuby.  I used rvm to switch between the ruby interpretors to perform this test (<http://beginrescueend.com/>).

For the first test, I used the native (Matz) ruby interpreter (ruby 1.8.7 (2010-01-10 patchlevel 249) [universal-darwin11.0]) on a fairly serious quad core i7 laptop.  This is the native version of ruby that comes with MacOS X.

```console
Rehearsal -----------------------------------------------------------------
distance_ruby                  20.380000   0.070000  20.450000 ( 20.449417)
------------------------------------------------------- total: 20.450000sec

                                    user     system      total        real
distance_ruby                  20.370000   0.070000  20.440000 ( 20.431304)

Rehearsal -----------------------------------------------------------------
distance_c                      0.040000   0.000000   0.040000 (  0.040182)
-------------------------------------------------------- total: 0.040000sec

                                    user     system      total        real
distance_c                      0.040000   0.000000   0.040000 (  0.040385)
```

Note that the first set of benchmarks show the pure ruby times and the second show the inline C times. The inline C version of the algorithm is over 500x faster!

The the second set of tests, I used the JRuby interpreter.  It is quite an impressive environment for running ruby.  It's performance is on par with the latest 1.9 version of the Matz ruby interpreter.

```console
Rehearsal -----------------------------------------------------------------
distance_ruby                   4.795000   0.000000   4.795000 (  4.795000)
-------------------------------------------------------- total: 4.795000sec

                                    user     system      total        real
distance_ruby                   3.989000   0.000000   3.989000 (  3.989000)

Rehearsal -----------------------------------------------------------------
distance_java                   0.130000   0.000000   0.130000 (  0.130000)
-------------------------------------------------------- total: 0.130000sec

                                    user     system      total        real
distance_java                   0.065000   0.000000   0.065000 (  0.065000)
```

Note how simply running the pure ruby version of the algorithm is over 5 times faster than the 1.8 version of the native (Matz) interpreter. Also, due to the dynamic optimizations of the Java VM, the 'Rehearsal' run is about 20% slower than the subsequent run.

The inline Java version of the algorithm proves to be over 60 times faster than the pure ruby version running within JRuby. However, the inline Java version comes in at over 300x faster than the pure ruby version running in the native (Matz) interpreter (v1.8.7). Again, the dynamic performance optimizations make the inline Java version test twice as fast as the "Rehearsal" run. Actual inline Java code can be optimized by the Java VM better than ruby source filtered through the JRuby interpreter.

The benchmark class looks like the following:

```ruby
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
```

###Summary

Inlining C or Java code with RubyInline and java_inline is a huge win for optimizing CPU intensive code.  The examples provided here should be enough to get you going.  If you have any questions or comments, please let me know!