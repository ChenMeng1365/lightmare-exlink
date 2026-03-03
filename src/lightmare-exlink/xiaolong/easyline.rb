#coding:utf-8

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
    src = src.compact.select{|s|!s.empty?}.map{|s|mfa(s)}
    return src, cmt
  end

  def handle src
    src.inject([]) do|dst, s|
      f,a = s
      evaluted = EasyLine::Handler.respond_to?(f) ? EasyLine::Handler.send(f, a) : EasyLine::Handler.eval(f, a)
      evaluted ? (dst << evaluted) : dst
    end
  end

  def runner
    return %q{#!/usr/local/bin/ruby
#coding:utf-8
require 'lightmare-exlink'

begin # make instance
  inst = XiaoLong.gen_root
  [
    ((target))
  ].each do|item|
    path, val = item.keys.first, item.values.first
    current = XiaoLong.asym path.sub('#/definitions/((root))/',''), inst
    current.val = val
  end
  File.write "((name)).json",JSON.pretty_generate(inst.to_doc(lambda{|n|n.val}))
end}
  end

  def translate option
    name, root, debug = option[:name], option[:root], option[:debug]
    raise "Please input pathroute file(*.lm) path" unless name
    raise "Please input root name" unless root
    name = name+'.lm' unless name[-3..-1]=='.lm'
    source, comment = EasyLine.source File.read(name)
    target = EasyLine.handle source
    File.write "#{name}.rb", runner.gsub("    ((target))",target.map{|t|"    #{t}"}.join(",\n")).gsub("((name))",name).gsub("((root))",root)
    `ruby #{name}.rb`
    `rm #{name}.rb` unless debug=='-d'
  end
end

module EasyLine
  module Handler
    module_function

    def path routes
      @head = routes.pop || '#/definitions'
      return nil
    end

    def bind args
      @list ||= []
      @list += args
      return nil
    end

    def unbind nums
      @list ||= []
      nums << '1' if nums.empty?
      nums.pop.to_i.times{ @list.pop }
      return nil
    end

    def eval expr, val
      @list ||= []
      iter = [@head, expr].compact.join('/')
      @list.each{|item|iter = iter.sub('*/',"*[#{item}]/")}
      return {iter=>transform(val.pop)}.to_s
    end

    def transform atom
      atom.is_a_number? and return atom.to_number
      atom.is_boolean?  and return atom.to_boolean
      return atom
    end
  end
end

class String
  def is_a_number?
    /^\-?\d+(\.\d+)?(e\-?\d+)?$/.match(self)
  end

  # if not a number, not transform
  def to_number
    is_a_number? ? (self.include?('.') || self.include?('e') ? self.to_f : self.to_i) : self
  end

  def is_boolean?
    ['true','false'].include?(self.downcase)
  end

  def to_boolean
    is_boolean? ? eval(self.downcase) : self
  end
end

__END__
#!/usr/local/bin/ruby
#coding:utf-8
require 'lightmare-exlink'
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