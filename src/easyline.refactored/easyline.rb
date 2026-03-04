#coding:utf-8

require_relative 'parser'
require_relative 'handler'
require_relative 'type'

module EasyLine
  module_function

  def translate option
    name, root, debug = option[:name], option[:root], option[:debug]
    format = option[:format] || :json
    raise "Please input pathroute file(*.lm) path" unless name
    
    filepath = nil
    filepath = File.exist?(name)&&!File.directory?(name) ? name : nil
    unless filepath
      temp = name+'.lm'
      filepath = File.exist?(temp)&&!File.directory?(temp) ? temp : nil
    end
    unless filepath
      raise "[LoadError]#{filepath}"
    end

    sources, comment = EasyLine::Parser.source(EasyLine::Parser.load(filepath))
    
    target = []
    sources.each do|mod, source|
      take = mod=='GLOBAL' ? root : mod
      make = EasyLine.handle(source, take).map{|t|"    #{t}"}.join(",\n")
      make = make.gsub("((root))/","") if root=='CUT'
      title = root ? root : mod
      target << make.gsub("((root))",title)
    end

    filepath = name[-3..-1]=='.lm' ? name[0..-4] : name
    File.write "#{name}.rb", EasyLine.runner(format).gsub("    ((target))",target.join(",\n")).gsub("((name))",filepath)
    `ruby #{name}.rb`
    `rm #{name}.rb` unless debug=='-d'
  end
end

__END__
#!/usr/local/bin/ruby
#coding:utf-8
require_relative 'easyline'
name, root, debug = ARGV[0..2]

# 一个简单的配置文件到json的转化脚本
# $: ./gen-lmex.rb [dir:]*SCRIPT_PATH MODULE_NAME [DEBUG_FLAG]*
if name[0..3]=='dir:'
  dir = name[4..-1].split("/")
  dir << "*.lm"
  Dir["#{dir.join('/')}"].each do|path|
    EasyLine.translate(name: (path[-3..-1]=='.lm' ? path[0..-4] : path), root: root, debug: debug)
  end
else
  EasyLine.translate(name: (name[-3..-1]=='.lm' ? name[0..-4] : name), root: root, debug: debug)
end