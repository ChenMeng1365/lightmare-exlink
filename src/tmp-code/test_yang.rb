#!/usr/local/bin/ruby
#coding:utf-8
require 'whittle'

class XiaoLong < Whittle::Parser

  rule(WHITESPACE:  /\s+/).skip!
  # rule(ENTER: /[\r]\n/).as{"\n"}

  rule(COMMENT: /\/\/.*/)
  rule(COMSGMT: /\/\*.*\*\//m)

  rule(DESCRIPTION: /description[\t|[\r]\n|\ ]*".*";/m)
  rule(ORGANIZATION: /organization[\t|[\r]\n|\ ]*".*";/m)
  rule(CONTACT: /contact[\t|[\r]\n|\ ]*".*";/m)

  rule(REVISION: /revision( )*(\w*)/)
  rule(SUBMODULE: /submodule( )*(\w*)/)



  rule('{')
  rule('}')
  rule('[')
  rule(']')
  rule('(')
  rule(')')

  rule(WORD: /.*/)


  rule(:REVISIONBLK) do|r|
    r[:REVISION, '{', :SEQUENCE, '}' ].as do|revision, _, sequence, _|
      rev, date = revision.strip.split(' ')
      {[rev,date]=>sequence}
    end
  end

  rule(:SUBMODBLK) do|r|
    r[:SUBMODULE, '{', :SEQUENCE, '}' ].as do|submodule, _, sequence, _|
      subm, name = submodule.strip.split(' ')
      {[subm,name]=>sequence}
    end
  end
 
  rule(:NORMBLK) do|r|
    r['{',:SEQUENCE,'}'].as do|_, sequence, _|
      sequence
    end
  end

  rule(:SEQUENCE) do|r|
    # r[:SEQUENCE,:ENTER,:SEQUENCE].as{|head,_,tail|head+["\n"]+tail}
    r[:REVISIONBLK,:SEQUENCE].as do|rblk,sequence|
      sequence << rblk
      sequence
    end

    r[:SUBMODBLK, :SEQUENCE].as do|sblk, sequence|
      sequence << sblk
      sequence
    end

    r[:NORMBLK, :SEQUENCE].as do|block,sequence|
      sequence << block
      sequence
    end

    r[:DESCRIPTION, :SEQUENCE].as do|desc,sequence|
      content = eval desc.split("description")[1].to_s.strip
      sequence << {DESCRIPTION: content}
      sequence
    end

    r[:ORGANIZATION, :SEQUENCE].as do|organ,sequence|
      content = eval organ.split("organization")[1].to_s.strip
      sequence << {ORGANIZATION: content}
      sequence
    end

    r[:CONTACT, :SEQUENCE].as do|cont,sequence|
      content = eval cont.split("contact")[1].to_s.strip
      sequence << {CONTACT: content}
      sequence
    end

    r[:WORD,:SEQUENCE].as do|word,sequence|
      sequence << {WORD: word}
      sequence
    end

    r[:COMMENT, :SEQUENCE].as do|comment,sequence|
      sequence << {COMMENT: comment}
      sequence
    end

    r[:COMSGMT, :SEQUENCE].as do|comment,sequence|
      sequence << {COMMENT: comment}
      sequence
    end
    
    r[].as{[]}
  end

  start(:SEQUENCE)
end
