#coding:utf-8

class String
  # "Path" => Folder
  def directory_detection
    folder = {}
    Dir["#{self}/*"].each do|path|
      next if ["..","."].include?(path)
      epath = File.expand_path(path)
      pathname = epath.split("/")[-1]
      if File.directory?(epath)
        sub = epath.directory_detection
        folder.merge!(pathname=>sub) # epath
      else
        folder[pathname] = "file" # epath
      end
    end
    return folder
  end
end

class Hash
  # Folder => Paths
  def paths
    traces = []
    self.each do|name,tag|
      traces << [name]
    end
    self.each do|name,tag|
      if tag.is_a?(Hash)
        subs = tag.paths
        new_traces = []
        traces.each do |trace|
          if trace[-1] == name
            new_sub = []
            subs.each{|vector|new_sub << trace + vector}
            new_traces += new_sub
          else
            new_traces << trace
          end
        end
        traces = new_traces
      end
    end
    return traces
  end
  
  def find_path nodename
    result = []
    self.paths.each do|path|
      result << path.join("/") if path.join("/").include?(nodename)
    end
    return result
  end
end


class Object
  def try(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b) if respond_to?(a.first)
    end
  end
end

class NilClass
  def try(*args)
    nil
  end
end

=begin # example
  @person = Object.new
  class << @person
    def first_name
      'a'
    end
    def last_name
      'z'
    end
  end

  # 尝试一个方法,如不存在则返回nil(减少异常处理)
  p @person.try(:name)
  # 尝试一个块
  p @person.try{|p|"#{p.first_name} #{p.last_name}"}
=end


# The Class Tree is a recursive hash-generator based on Hash.
# The examples of usage see below of the class definition.
class Tree < Hash
  VERSION = '0.2.0'

  def self.init
    Tree.new{|tree, path|tree[path] = Tree.new(tree,&tree.default_proc) }
  end

  def self.clear
    self.init
  end

  attr_accessor :parent

  def initialize parent=nil
    @parent=parent
    super()
  end

  def [] key
    unless key.instance_of?(String) && key.include?('/')
      child = super(key)
      child.parent = self if child.respond_to? :parent
      return child
    end
    key.include?('/') ? send(:route,key) : super(key)
  end

  def []= key, value
    unless key.instance_of?(String) && key.include?('/')
      super(key,value)
      child = self[key]
      child.parent = self if child.respond_to? :parent
      return child
    end
    key.include?('/') ? (key=='/' ? (raise PathError, "Class Tree can't use '/' as a key except rootself.") : send(:mount,key,value)) : super(key,value)
  end

  def route path
    unless path.instance_of?(String) && path.include?('/')
      post = self[path]
      post.parent = self if post.respond_to? :parent
      return post
    end
    return self if path=='/'
    hops = path.split('/')
    hops.delete ''
    curr = hops.shift
    if hops.empty?
      self[curr]
    else
      # if a leaf exists, any path walkthrough leaf would not pass;
      # if no leaf exists, any path walkthrough could be pass.
      raise PathError, "The current expected path`#{path}` not exist." unless self[curr].respond_to? :route
      self[curr].send "route", hops.join('/')
    end
  end

  # Caution: #mount will arrive the deepest leaf and change the passthrough
  def mount path, store
    unless path.instance_of?(String) && path.include?('/')
      self[path]=store
      post = self[path]
      post.parent = self if post.respond_to? :parent
      return post
    end
    raise PathError, "Class Tree can't mount an value on the root." if path=='/'
    hops = path.split('/')
    hops.delete ''
    curr = hops.shift
    if hops.empty?
      self[curr]=store
      self.delete nil # except ['/']=store to {nil=>store}
    else
      self[curr]=Tree.init
      # self[curr].send "route", hops.join('/')
      self[curr].send "mount", hops.join('/'), store
    end
  end

  # Caution: #emerge can adapt on HashObject but loose the tree-ability
  def emerge path, tree
    if tree.is_a?(Hash)
      hops = path.split("/")
      popz = hops.pop
      curr = hops.join('/')
      target = hops.empty? ? self[popz] : self.route(curr)
      raise PathError, "The current node [\"#{path}\"]=>#{target} not respond to contact/merge." unless target.respond_to? :route
      target.merge!(tree)
      return target
    end
  end

  def contact path, tree
    if tree.is_a?(Tree)
      target = self.route path
      raise PathError, "The current node [\"#{path}\"]=>#{target} not respond to contact/merge." unless target.respond_to? :route
      target.merge!(tree)
      tree.parent = target
    end
  end

  class PathError < Exception
  end
end

=begin
  # 奇怪的数据结构增加了!!!
  a = Tree.init

  # 逐个赋值
  a[1][2][3] = :'4'
  a['1']['2']['3']=4
  p a
  puts Array.new(32,'-').join

  # 直接挂载
  a.mount '1/2/3/4/5/6', '7'
  p a
  a['1/2/3'] = 4
  p a
  puts Array.new(32,'-').join

  # 不能给根目录赋值
  begin
    a['/'] = :root
  rescue Tree::PathError => exception
    puts "#{exception.class}: #{exception.message}\n  #{exception.backtrace.join("\n  ")}"
  end
  begin
    a.mount '/', :home
  rescue Tree::PathError => exception
    puts "#{exception.class}: #{exception.message}\n  #{exception.backtrace.join("\n  ")}"
  end
  p a.route('/')==a['/']
  puts Array.new(32,'-').join

  # 合并到某分支，连接到路径
  b = Tree.init
  b['a/b/c'] = :d
  a.emerge '1/2/3', b['a']
  p a # a['1/2/b'].parent==a['1/2/3'].parent # a['1/2/3'] is 4 and not respond to parent
  begin
    a.contact '1/2/3', b['a']
  rescue Tree::PathError => exception
    puts "#{exception.class}: #{exception.message}\n  #{exception.backtrace.join("\n  ")}"
  end
  a.contact '1/2', b
  p a
  puts Array.new(32,'-').join

  # 回溯父节点
  t = Tree.init
  p t['a/b/c'] = :d
  p t
  puts Array.new(32,'-').join
  p '1:',t['1'],t['1/'].parent
  puts Array.new(32,'-').join
  p '1/2:',t['/1/2'],t['1/2'].parent
  puts Array.new(32,'-').join
  p '1/2/3:',t['1/2/3/'],t['1/2/3'].parent
  puts Array.new(32,'-').join
  p '1/2/3/4:',t['1/2/3/4'],t['1/2/3/4'].parent
  puts Array.new(32,'-').join
  p 'a:',t['a'],t['a'].parent
  puts Array.new(32,'-').join
  p 'a/b:',t['a/b'],t['a/b'].parent
  puts Array.new(32,'-').join
  p 'a/b/c:',t['a/b/c'],t['/a/b/c'].try(:parent)
  puts Array.new(32,'-').join
  p 'a/b/c/d:',(begin;t['a/b/c/d'];rescue(Exception);'cant pass path="a/b/c/d" with leaf["a/b/c"]';end)
  puts Array.new(32,'-').join
=end


class Object
  #######################################################
  # walkthrough function-chain
  #######################################################
  
  # CALL: obj.sends(func1, func2, func3, ...)
  # RETN: obj.func1.func2.func3...
  def sends *funcs
    target = self
    funcs.each do|func|
      if func.is_a?(Symbol) or func.is_a?(String)
        target = target.send(*func)
      elsif func.is_a?(Array)
        target = target.send(*func)
      elsif func.instance_of?(Proc)
        target = func.call(*target)
      end
    end
    return target
  end
  
  # CALL: obj.maps(func1, func2, func3, ...)
  # REPR: ... func3.call( func2.call( func1.call(obj) ) )
  # RETN: [stack1, stack2, stack3, ...]
  def mapr *funcs
    red, target = [], self
    funcs.each do|func|
      if func.is_a?(Symbol) or func.is_a?(String)
        target = target.send(*func)
      elsif func.is_a?(Array)
        target = target.send(*func)
      elsif func.instance_of?(Proc)
        target = func.call(*target)
      end
      red << target
    end
    return red
  end
  
  # CALL: obj.cond_ins(attr1, attr2, attr3, ...)
  # REPR: obj.attr1 && obj.attr1.attr2 && obj.attr1.attr2.attr3... 
  # RETN: obj.attr1...attrn/false (false must be specified literally)
  def cond_insect *funcs
    target = self
    flag = funcs.inject(true) do|flag, func|
      if func.is_a?(Symbol) or func.is_a?(String)
        target = target.send(*func)
      elsif func.is_a?(Array)
        target = target.send(*func)
      elsif func.instance_of?(Proc)
        target = func.call(*target)
      end
      flag && target
    end
  end

  # CALL: obj.cond_union(attr1, attr2, attr3, ...)
  # REPR: obj.attr1 || obj.attr1.attr2 || obj.attr1.attr2.attr3...
  # RETN: obj.attrX (Y>X, when obj.attrY is false/not exist, obj.attrX is the first not false)
  def cond_union *funcs
    target = self
    flag = funcs.inject(false) do|flag, func|
      if func.is_a?(Symbol) or func.is_a?(String)
        target = target.send(*func)
      elsif func.is_a?(Array)
        target = target.send(*func)
      elsif func.instance_of?(Proc)
        target = func.call(*target)
      end
      flag || target
    end
  end
  
  #######################################################
  # map-reverse function-chain
  # 
  # Tips:
  # map := obj.map{|o|func(o)}
  # map-reverse := funcs.map{|func|func(obj)}
  #######################################################

  # CALL: obj.check_insect(cond1, cond2, cond3, ...)
  # REPR: cond1(obj) && cond2(obj) && cond3(obj) ...
  # RETN: blockn(obj)/false (false must be specified)
  def check_insect *funcs
    flag = funcs.inject(true) do|flag, func|
      if func.is_a?(Symbol) or func.is_a?(String)
        flag && self.send(func)
      elsif func.is_a?(Array)
        flag && self.send(*func)
      else
        flag && func.call(*self)
      end
    end
  end
  
  # CALL: obj.check_union(cond1, cond2, cond3, ...)
  # REPR: cond1(obj) || cond2(obj) || cond3(obj) ...
  # RETN: true/false
  def check_union *funcs
    flag = funcs.inject(false) do|flag, func|
      if func.is_a?(Symbol) or func.is_a?(String)
        flag || self.send(func)
      elsif func.is_a?(Array)
        flag || self.send(*func)
      else
        flag || func.call(*self)
      end
    end
  end

end


=begin # example
  class A1
    def a2
      A2.new
    end
  end

  class A2
    def a3
      A3.new
    end
  end

  class A3
    def a4
      A4.new
    end
  end

  class A4
    def a5
      false
    end
  end

  class String
    def to_bill
      return false
    end
  end

  puts "a.sends(:b,:c,:d) => #{A1.new.sends(:a2,Proc.new{|i|i.send :a3},:a4)} #=> #<A4 ...>"
  puts "a.cond_insect(:b,:c,:d) => #{A1.new.cond_insect(:a2,lambda{|s|s.send :a3},:a4 ) ? :true : :false}"
  puts "a.cond_union(:b,:c,:d) => #{A3.new.cond_union(:a4,Proc.new{|s|s.a5},:to_s,'to_bill' ) ? :true : :false} #=> #<A4 ...> "
  puts "a.mapr(fun1, fun2, fun3) => #{"15a".mapr(lambda{|s|s.to_i+1}, lambda{|s|s.to_s+"b"}, lambda{|s|s[-1]}).last}"
  puts "a.check_insect(cond1, cond2, cond3) => #{"15a".check_insect( lambda{|s|s.to_i < 20}, lambda{|s|s.to_i > 10}, lambda{|s|s.size==3} )}"
  puts "a.check_union(cond1, cond2, cond3) => #{"15a".check_union( lambda{|s|s.is_a?(Symbol)}, lambda{|s|s.respond_to?(:to_json)}, lambda{|s|s.instance_of?(Module)} )}"

  OUTPUT = %Q{
    a.sends(:b,:c,:d) => #<A4:0x0000000006425648> #=> #<A4 ...>
    a.cond_insect(:b,:c,:d) => true
    a.cond_union(:b,:c,:d) => true #=> #<A4 ...> 
    a.mapr(fun1, fun2, fun3) => b
    a.check_insect(cond1, cond2, cond3) => true
    a.check_union(cond1, cond2, cond3) => false
  }
=end

class String
  def self.load_from path
    buffer = File.open(path,'r'){|f|f.read}
    if buffer.encoding=="GBK"
      begin
        return buffer.encode("UTF-8") 
      rescue Encoding::UndefinedConversionError=>e
        if e.message.include?("from GBK to UTF-8")
          buffer.force_encoding("UTF-8")
        else
          raise "#{e.message} (#{e.class})"
        end
      end
    end
    return buffer
  end
  
  def save_into path
    File.open(path,'w'){|f|f.write(self)}
  end
  
  def save_binary_into path
    File.open(path,'wb'){|f|f.write(self)}
  end

  def append_into path
    unless File.exist?(path)
      save_into(path)
    else
      File.open(path,'a'){|f|f.write(self)}
    end
  end
end

require 'json'
require 'yaml'

class File
  def self.load_json filepath
    path = filepath.include?('.json') ? filepath : filepath+".json"
    context = File.open(path,'r'){|f|f.read}.force_encoding("UTF-8")
    JSON.parse(context)
  end
  
  # ...
  # yaml = YAML.dump( obj )
  # obj = YAML.load( yaml )
  # File.open( 'path.yaml', 'w' ) do |out| YAML.dump( obj, out ) end
  # obj = YAML.load_file("path.yaml")
  def self.load_yaml filepath
    path = filepath.include?('.yml') ? filepath : filepath+".yml"
    context = File.open(path,'r'){|f|f.read}.force_encoding("UTF-8")
    YAML.load(context)
  end

  def self.clear_edit_backfile path
    if File.exist?(path) && path[-1]=='~'
      File.delete(path)
      puts "Delete #{path} successfully!"
    else
      puts "Cannot delete #{path}, just pass away!"
    end
  end

  def self.clear_edit_backfile_path path='.'
    Dir["#{path}/*~"].each do|path|
      begin
        File.delete(path)
        puts "Delete #{path} successfully!"
      rescue
        puts "Cannot delete #{path}, just pass away!"
      end
    end
  end

  def self.diff left_path, right_path, report_path='diff.tmp'
    `echo "\n#{Array.new(64,'-').join}\n" >> #{report_path}`
    `echo "<< #{left_path} <=> #{right_path} >>\n" >> #{report_path}`
    `diff #{left_path} #{right_path} >> #{report_path}`
  end

  def self.diffs adir, bdir, head='.'
    alist = (head+'/'+adir).directory_detection.paths.map{|path|path.join('/')}
    blist = (head+'/'+bdir).directory_detection.paths.map{|path|path.join('/')}

    onlyalist = alist - blist
    onlyblist = blist - alist
    commnlist = alist & blist

    report = []
    unless onlyalist.empty?
      report << "only #{adir} exist files:\n"
      report += onlyalist.map{|path|path}
      report << '' << Array.new(64,'=').join
    end

    unless onlyblist.empty?
      report << "\nonly #{bdir} exist files:\n"
      report += onlyblist.map{|path|path}
      report << '' << Array.new(64,'=').join
    end

    unless commnlist.empty?
      report << "\ncommon files comparison:"
      commnlist.each do|path|
        self.diff("#{head}/#{adir}/#{path}", "#{head}/#{bdir}/#{path}", 'diff.tmp')
      end
      File.exist?('diff.tmp') and report << File.read('diff.tmp')
      File.exist?('diff.tmp') and File.delete('diff.tmp')
    end

    return report.join("\n")
  end
end

module Diff
  module_function

  # 该方法只用来排成两列显示, 并不真正执行比较, 已经有File.diff/File.diffs完成该工作
  def show text1, text2, shift=0
    list1 = text1.instance_of?(String) ? text1.split("\n") : text1
    list2 = text2.instance_of?(String) ? text2.split("\n") : text2
    max1 = list1.map{|r|r.length}.max
    max2 = list2.map{|r|r.length}.max
    shift > 0 and (list1 = Array.new(shift, "")+list1) #and (list2 += Array.new(shift, ""))
    shift <= 0 and (list2 = Array.new(shift, "")+list2)# and (list1 += Array.new(shift, ""))
    size = [list1.size, list2.size].max+(shift>0 ? shift : shift*(-1))
    rows = []
    size.times.each do|index|
      rows << [
        list1[index].to_s+Array.new(max1 - list1[index].to_s.length, " ").join, 
        list2[index].to_s+Array.new(max2 - list2[index].to_s.length, " ").join
      ]
    end
    return rows
  end
  
  def shift text, index, shift=1
    list = text.instance_of?(String) ? text.split("\n") : text
    shift.times.each do list.insert(index,"") end
    return list.join("\n")
  end
end

class Integer
  def line;return self;end
  def lines;return self;end
  def row;return self;end
  def rows;return self;end
end

=begin # example
  tab1 = File.read("1.txt")
  tab2 = File.read("2.txt")

  text1 = Diff.shift tab1, 2.row, 1.row
  text1 = Diff.shift text1, 5.line, 1.row
  text1 = Diff.shift text1, 8.line, 2.rows
  text2 = Diff.shift tab2, 7.row, 1.line
  text2 = Diff.shift text2, 11.row, 1.line
  
  tab = Diff.show text1, text2
  File.write "tab.txt", tab.map{|t|t.join("|")}.join("\n")
=end
