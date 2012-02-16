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
