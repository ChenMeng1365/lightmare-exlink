#!/usr/local/bin/ruby
#coding:utf-8

dst = "../tmp"
Dir.mkdir(dst) unless File.exist?(dst)

Dir["./*.yang"].each do|yang|
  yin = yang.gsub(".yang",'.yin')
  `pyang -f yin -o #{yin} #{yang} 2>> a-trans.log`
  `mv #{yin} #{dst}`
end
