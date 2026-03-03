#!/usr/local/bin/ruby
#coding:utf-8

['yaml', 'fileutils','./conf'].each{|mod|require mod}
索引 = YAML.load File.read("#{$config}/path.yaml")

=begin
tests
  ├── data
  ├── features
  ├── output
  ├── proofs
  ├── step_defs
  ├── pipelines
  └── units
=end
begin # pytest-framework (unittest + bdd + special)
  [
    "tests", 
    "tests/data", "tests/output", 
    "tests/units", "tests/pipelines", 
    "tests/features", "tests/step_defs", 
    "tests/proofs"
  ].each do|模块|
    目录 = "#{索引['pytest-frame']}/#{模块}"
    !File.exist?(目录) and Dir.mkdir(目录)
  end
end

begin # pytest.ini
  文件名 = 'pytest.ini'
  File.write ".datahouse/#{文件名}","[pytest]\nmarkers=\n  unfinished: uncom\n  finished: com"
  FileUtils.cp ".datahouse/#{文件名}", "#{索引[文件名]}/#{文件名}" unless File.exist?("#{索引[文件名]}/#{文件名}")
end

begin # pytest-cmd as pt
  编号名 = 'pytest-cmd'
  文件名 = 'pt.sh'
  File.write ".script/#{文件名}","cd #{索引[编号名]}\n./clear-cache.sh\npytest tests/step_defs/*$1* $2"
  File.chmod 0775, ".script/#{文件名}"
  FileUtils.cp ".script/#{文件名}", "#{索引[编号名]}/#{文件名}" unless File.exist?("#{索引[编号名]}/#{文件名}")
end

begin # pytest-cmd as pp
  编号名 = 'pytest-cmd'
  文件名 = 'pp.sh'
  File.write ".script/#{文件名}","cd #{索引[编号名]}\n./clear-cache.sh\npytest tests/pipelines/*$1* $2"
  File.chmod 0775, ".script/#{文件名}"
  FileUtils.cp ".script/#{文件名}", "#{索引[编号名]}/#{文件名}" unless File.exist?("#{索引[编号名]}/#{文件名}")
end

begin # pytest-output
  编号名 = 'pytest-output'
  文件名 = 'output.rb'

  File.write ".script/#{文件名}", DATA.read
  File.chmod 0775, ".script/#{文件名}"
  FileUtils.cp ".script/#{文件名}", "#{索引[编号名]}/#{文件名}"
end

__END__
#!/usr/local/bin/ruby

# > output.rb back SELECTOR [TAG]
if ARGV[0]=='back'
  tag = ARGV[2] || Time.new.strftime("%Y%m%d%H")
  Dir["tests/output/*#{ARGV[1]}*"].each do|path|
    next if path[-4..-1]=='.bak'
    File.rename path,path+".#{tag}.bak"
  end
end

# > output.rb rollback SELECTOR [TAG]
if ARGV[0]=='rollback'
  tag = ARGV[2]
  Dir["tests/output/*#{ARGV[1]}*"].each do|path|
    newpath = if path[-4..-1]=='.bak' && tag
      path.gsub(".#{tag}.bak","")
    elsif path[-4..-1]=='.bak' && !tag
      path.split(".")[0..-3].join('.')
    else
      path
    end
    File.rename path,newpath if path!=newpath
  end
end

# > output.rb clear SELECTOR [all]
if ARGV[0]=='clear'
  not_clear_all = ARGV[2]!='all'
  Dir["tests/output/*#{ARGV[1]}*"].each do|path|
    next if not_clear_all && path[-4..-1]=='.bak'
    File.delete path
  end
end