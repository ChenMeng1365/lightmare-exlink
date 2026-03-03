#!/usr/local/bin/ruby
#coding:utf-8

$:<<'.'
%w{yaml lib/cc-cache lib/pynote}.map{|mod|require mod}

if ARGV.empty?
  # warn "At least one argument for folder"

  conf = YAML.load(File.read("PycodeNote.yml"))
  filepaths = []
  Dir["#{conf['src']}/#{conf['package']}/*.py"].each do|path|
    next unless path.include?(conf['matcher'])
    filepaths << path
  end
  list = filepaths.map{|file|"[#{conf['header']}:#{file.split("/")[-1]}](#{file})"}.join("\n")
  content = PyNote.batch_mark(filepaths,:NOTAG)
  File.write "#{conf['dst']}/#{conf['header']}.note.md","#{list}\n\n#{content}"

else
  basedir = ARGV[0]
  if basedir[-3..-1]=='.py'
    content = PyNote.mark(basedir,:NOTE)
  else
    filepaths = basedir.directory_detection.paths.map{|path|"#{basedir}/#{path.join('/')}"}
    content = PyNote.batch_mark(filepaths,:NOTAG)
  end
  File.write "#{basedir}.note.txt",content
end

__END__
src: 
dst: 
package: 
header: 
matcher: 