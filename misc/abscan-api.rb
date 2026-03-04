#!/usr/bin/env ruby
#coding:utf-8
features = ARGV + DATA.read.split("\n").map{|i|i.split(' ')}.flatten.uniq

path = "sup-doc-0926"

paths = Dir["./#{path}/*-mapping.txt"].inject([]) do|paths, workfile|
  paths += (File.read workfile).split("\n"); paths
end

selects = paths.select{|path|
  features.inject(true){|flag,feature|
    feat,logic = feature[0]=='-' ? [feature[1..-1],false] : [feature, true]
    flag&&(path.include?(feat)==logic)
  }
}
File.write "abscan-api.txt", selects.join("\n")

__END__
-operation -state