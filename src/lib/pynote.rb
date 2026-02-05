#coding:utf-8

module PyNote
  module_function

  def main line,tag=:NOTAG
    return nil unless line.include?('__main__') && line.include?('__name__')
    return nil unless !line.index('#') || line.index('__name__') <= line.index('#') || line.index('__main__') <= line.index('#')
    return mainote(line,tag)
  end

  def mainote head,tag=:NOTAG
    return "MAIN_ENTRY\n"
  end

  def require line,tag=:NOTAG
    return nil unless line.include?('import ')
    return nil unless !line.index('#') || line.index('import') <= line.index('#')
    return impnote(line,tag)
  end

  def impnote head,tag=:NOTAG
    note = tag==:NOTE ? "\nNOTE: \n" : ""
    seq = head.split('#')[0].split(' ')
    from, import, as = ['from','import', 'as'].map{|kw|seq.send(:index, kw)}

    pkg = from ? seq[from+1] : (import ? seq[import+1] : nil)
    mod = (from && import) ? seq[(import+1)..-1].join(' ').split(" as ")[0] : (import ? seq[import+1] : nil)
    nck = as ? seq[as+1] : nil
    return "import #{[pkg,mod].uniq.join(' :: ')}#{(nck ? " => #{nck}" : '')}#{note}"
  end

  def class line,tag=:NOTAG
    return nil unless line.include?('class ')
    return nil unless !line.index('#') || line.index('class') <= line.index('#')
    return clsnote(line,tag)
  end

  def clsnote head,tag=:NOTAG
    note = tag==:NOTE ? "\n" : ''
    head.strip[0..5]=='class ' and return head.strip+"#{note}"
    return nil
  end

  def method line,tag=:NOTAG
    mi,ci = line.index('def '), line.index('#')
    !mi and         return nil
    mi  and !ci and return self.defnote(line,tag)
    mi < ci and     return self.defnote(line,tag)
    return nil
  end

  def defnote head,tag=:NOTAG
    return [ head.strip,
      'NOTE: '#,'DESC: ','CALL: ','RETN: '
    ].join("\n")+"\n" if tag==:NOTE
    return head.strip#+"\n"
  end

  def mark path,tag=:NOTAG
    list = File.read(path).split("\n")
    abstract = []
    list.each_with_index do|line, index|
      abstract << [self.require(line,tag),index]
      abstract << [self.class(line,tag),index]
      abstract << [self.method(line,tag),index]
      abstract << [self.main(line,tag),index]
      abstract
    end
    abstract.delete_if{|abs|!abs[0]}
    content = abstract.map do|abs|
      declr  = abs[0]
      lineno = "%0d" % (abs[1].to_i+1)
      %Q{#{declr} [To](#{path}:#{lineno})}
    end.join("\n")
    return "[#{path.split("/")[-1]}](#{path})\n\n#{content}"
  end

  def batch_mark paths,tag=:NOTAG
    note = []
    paths.each do|path|
      next unless path[-3..-1]=='.py'
      note << PyNote.mark(path,tag)
    end
    puts paths.size
    return note.join("\n"+Array.new(128,'=').join+"\n\n")
  end
end
