#coding:utf-8

module EasyLine
  module Parser
    module_function

    def comment text
      src,cmt, flag, ftag = [], {}, :closed, nil
      text.gsub("\r",'').split("\n").each do|line|
        ref = line.strip
        if ref.include?("$::") or ref.include?("::$")
          if ref.include?("$::")
            code, desc = ref.split("$::")
            src << code.to_s.strip
            ftag = desc ? desc.to_s.strip : Object.new.object_id
            cmt[ftag] ||= []; cmt[ftag] << desc.to_s.strip
            flag = :open
          end
          if ref.include?("::$") && flag==:open
            rest = ref.split("$::")[1].to_s
            desc, code = rest.split("::$")
            src << code.to_s.strip if code && code!=''
            cmt[ftag] << desc.to_s.strip if desc && desc!=''
            flag = :closed
          end
          next
        end
        if flag==:open
          cmt[ftag] << ref.to_s.strip
        else
          src << ref.split("$:")[0].to_s.strip
        end
      end
      src = src.compact.select{|s|!s.empty?}
      return src, cmt
    end

    def source text
      sources, comment = EasyLine::Parser.comment(text)
      EasyLine::Handler.clear_modules
      
      sources.each do|code|
        if code[0..6]=='module '
          EasyLine::Handler.moduel code.split('module ')[1]
        elsif code[0..2]=='end' or code[0..2]=='fin'
          EasyLine::Handler.fin
        else
          EasyLine::Handler.push code
        end
      end
      
      intercodes = {}
      EasyLine::Handler.get_modules.each do|smod, part|
        intercodes[smod] = part.map{|s|func,*args=s.to_s.strip.split(' ');[func, args]}
      end
      return intercodes, comment
    end

    def load name
      raise "[LoadError]Please input pathroute file(*.lm) path" unless name
      filepath = nil
      filepath = File.exist?(name)&&!File.directory?(name) ? name : nil
      unless filepath
        temp = name+'.lm'
        filepath = File.exist?(temp)&&!File.directory?(temp) ? temp : nil
      end
      unless filepath
        raise "[LoadError]#{filepath}"
      end
      return File.read(filepath)
    end

  end
end