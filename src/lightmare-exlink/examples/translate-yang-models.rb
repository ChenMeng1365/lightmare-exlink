#!/usr/local/bin/ruby
#coding:utf-8

# USAGE: shell# ./script.rb $folder_name $formattor
# ARGV1: folder_name default in models/yang/
# ARGV2: formatter := json|yaml|yin|xml|swagger|uml|tree

# ※ 有些转换依赖了EagleUmlCommon插件, 但插件并不完美支持所有厂家, 还有些时候转换会报语法错误(非领域问题), 建议自己对照报错修改对应的py脚本

if ARGV.empty?
  # warn "WARN: Please specify the folder name($1) in models/ and the formatter($2) which prefer to be transformed.";exit
  require 'yaml'
  conf        = YAML.load(DATA.read) # or File.read("ModelExchangeTemplate.yml")
  src_path    = conf["src"]
  dst_path    = conf["dst"]
  foldername  = conf["workdir"]
  formatname  = conf["format"]
  dheader     = conf["header"]
  log_path    = "#{conf["log"]}/transerrors#{Time.new.strftime("%Y%m%d")}.log"

else # SCRIPT.SH $1:FOLDNAME $2:FORMATNAME
  foldername = ARGV[0]
  formatname = ARGV[1]

  if ARGV.size==1
    if ['-h','--help','help'].include? foldername.to_s.strip.downcase
      puts "USAGE:  yang-transform-batch.sh $DIRNAME $FORMATTER\nFORMAT: json|yaml|yin|xml|swagger"
    else
      warn "WARN: Please specify the formatter($2) which prefer to be transformed."
    end
    exit
  end

  src_path = "../.." # ~/workspace/dev
  dst_path = "../tmp"
  dheader  = ARGV[2] || foldername
  log_path = "#{dst_path}/transerrors#{Time.new.strftime("%Y%m%d")}.log"
end

formatter = {'json'=>'json','xml'=>'xml','yin'=>'xml','yaml'=>'yml','swagger'=>'json','uml'=>'uml','tree'=>'tree'}
unless formatter.keys.include?(formatname.downcase)
  warn "WARN: Unrecognized formattoer(#{formatname}) in list(#{formatter.keys.join(',')}).";exit
end

Dir.mkdir(dst_path) unless File.exist?(dst_path)
File.open(log_path,"a+"){|f|f.write "\n\n#{Array.new(32,'-').join} transform yang to #{formatname} at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{Array.new(32,'-').join}\n"}

Dir["#{src_path}/#{foldername}/*.yang"].each do|path|
  if formatname.downcase=='swagger'
    File.open(log_path,"a+"){|f|f.write "\n>>> transform #{path}\n"}
    `pyang --plugindir $EXT/git/EagleUmlCommon/YangJsonTools/ -f #{formatname} -p #{src_path}/#{foldername}/ -o #{dst_path}/#{dheader}##{path.split('/')[-1].gsub(".yang",".#{formatter[formatname]}")} #{path} --generate-rpc=False 2>> #{log_path}`
  else
    `pyang -f #{formatname} #{path} -o #{dst_path}/#{dheader}##{path.split('/')[-1].gsub(".yang",".#{formatter[formatname]}")} 2>> #{log_path}`
  end
end

__END__
--- # ModelExchangeTemplate.yml

# src: /home/ubuntu/workspace/doc
# dst: /home/ubuntu/workspace/dev/research/tmp
# workdir: ydk-yang-zte-m6000-v50010 # 模块路径修改这里
# header: '' # 添加模型前缀
# format: tree
# log: /home/ubuntu/workspace/dev/research/tmp

# src: /home/ubuntu/workspace/doc
# dst: /home/ubuntu/workspace/dev/research/tmp
# workdir: ydk-yang-zte-m6000-v50010 # 模块路径修改这里
# header: '' # 添加模型前缀
# format: swagger
# log: /home/ubuntu/workspace/dev/research/tmp

# src: /home/ubuntu/workspace/doc
# dst: /home/ubuntu/workspace/dev/research/tmp
# workdir: ydk-yang-zte-m6000-v50010 # 模块路径修改这里
# header: '' # 添加模型前缀
# format: yin
# log: /home/ubuntu/workspace/dev/research/tmp
