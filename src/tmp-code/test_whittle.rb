#!/usr/local/bin/ruby
#coding:utf-8
$LOAD_PATH << '.'
require 'whittle'

class XiaoLong < Whittle::Parser
  rule(WHITESPACE:  /(\s)+/).skip!

  rule('{')
  rule('}')
  rule(SUBMODULE: /submodule( )*(\w*)/)

  # rule(ENTER: /[\r]*\n/).skip!
  rule(WORD: /.+/)

  # rule(:SUBMODBLK) do|r|

  # end

  rule(:SEQUENCE) do|r|
    # r[:SEQUENCE,:ENTER,:SEQUENCE].as{|head,_,tail|head+["\n"]+tail}
    # r[:SUBMODBLK, :SEQUENCE].as do|sblk, sequence|
    #   sequence << sblk
    #   sequence
    # end

    r[:SUBMODULE, '{', :SEQUENCE, '}' ,:SEQUENCE].as do|submodule, _, subseq, _, sequence|
      subm, name = submodule.strip.split(' ')
      parent << {[subm, name]=>subseq}
      parent
    end

    r[:WORD,:SEQUENCE].as do|word,sequence|
      sequence << {WORD: word}
      sequence
    end

    r[].as{[]}
  end

  start(:SEQUENCE)
end


begin
  ps = XiaoLong.new
  v = ps.parse(DATA.read)
  pp v
rescue Whittle::UnconsumedInputError => exception
  puts exception.expected,exception.received, exception.line
end






__END__
submodule aaa {
  bbb
}