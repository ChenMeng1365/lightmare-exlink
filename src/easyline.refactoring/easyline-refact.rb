module EasyLine
  module_function

  def mfa line
    func, *args = line.to_s.strip.split(' ')
    return func, args
  end

  def source text
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
    
    mod = 'GLOBAL'
    src_tree = src.inject({}) do|tree, code|
      if code[0..6]=='module '
        mod = code.split('module ')[1]
        tree[mod] ||= []
      elsif code[0..2]=='end'
        # nothing to do
      else
        tree[mod] ||= []
        tree[mod] << code
      end
      tree
    end
    srcs = {}
    src_tree.each do|smod, part|
      srcs[smod] = part.map{|s|mfa(s)}
    end
    return srcs, cmt
  end

  def handle src,spc
    src.inject([]) do|dst, s|
      f,a = s
      evaluted = EasyLine::Handler.respond_to?(f) ? EasyLine::Handler.send(f, a) : EasyLine::Handler.eval(f, a, spc)
      evaluted ? (dst << evaluted) : dst
    end
  end

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

    sources, comment = EasyLine.source(File.read(filepath))
    target = []
    sources.each do|mod, source|
      take = mod=='GLOBAL' ? root : mod
      make = EasyLine.handle(source,take).map{|t|"    #{t}"}.join(",\n")
      make = make.gsub("((root))/","") if root=='CUT'
      title = root ? root : mod
      target << make.gsub("((root))",title)
    end

    filepath = name[-3..-1]=='.lm' ? name[0..-4] : name
    File.write "#{name}.rb", runner(format).gsub("    ((target))",target.join(",\n")).gsub("((name))",filepath)
    `ruby #{name}.rb`
    `rm #{name}.rb` unless debug=='-d'
  end
end


