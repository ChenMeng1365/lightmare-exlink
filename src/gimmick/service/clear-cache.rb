#!/usr/local/bin/ruby
#coding:utf-8

['yaml', 'fileutils','./conf'].each{|mod|require mod}
索引 = YAML.load File.read("#{$config}/path.yaml")

命令集 = []
文件名 = 'clear-cache'

目标 = '__pycache__'
命令集 += 索引[目标].inject([]) do|命令集, 目录|
  命令集 << (("#{目录}/#{目标}"=='/') ? "" : "rm -rf #{目录}/#{目标}")
end

目标 = '.pytest_cache'
命令集 += 索引[目标].inject([]) do|命令集, 目录|
  命令集 << (("#{目录}/#{目标}"=='/') ? "" : "rm -rf #{目录}/#{目标}")
end

目标 = '.idea'
命令集 += 索引[目标].inject([]) do|命令集, 目录|
  命令集 << (("#{目录}/#{目标}"=='/') ? "" : "rm -rf #{目录}/#{目标}")
end

File.write ".script/#{文件名}.sh", 命令集.join("\n")
File.chmod 0775, ".script/#{文件名}.sh"
FileUtils.cp ".script/#{文件名}.sh", "#{索引[文件名]}/#{文件名}.sh"
