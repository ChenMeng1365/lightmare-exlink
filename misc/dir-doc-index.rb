#!/usr/local/bin/ruby
#coding:utf-8

# 批量
Dir["./*"].each do|path|
  next if path.include?("其他") or ['.rb','.md'].include?(path[-3..-1])
  report = ["# #{path.split('/')[-1]}",""]

  Dir["#{path}/*"].each do|sub|
    # if sub.include?('#')
    #   old_path = sub.split("/")[0..-2]
    #   new_path = (old_path+[sub.split("/")[-1].split("#")[1]]).join("/")
    #   File.rename sub, new_path
    # else
    #   old_path = sub
    #   new_path = sub
    # end
    
    contrast_path = File.expand_path(sub).gsub("/home/leoma/workspace/","../../../")
    report << "[#{sub.split("/")[-1]}](#{contrast_path})"
  end
  File.write "#{path.split("/")[-1]}.md", report.join("\n")
end

report = ["# ~/workspace/doc:index",""]
Dir["./*.md"].each do|subpath|
  report << "#"+File.read(subpath)
end
File.write "doc-index.md", report.join("\n")

# 单个
# report = ["# #{ARGV[0]}",""]
# Dir["#{ARGV[0]}"].each do|path|
#   report << "[#{path.split("/")[-1]}](#{File.expand_path(path)})"
# end
# File.write "index.md", report.join("\n")
