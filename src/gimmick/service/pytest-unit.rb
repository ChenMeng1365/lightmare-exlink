#!/usr/local/bin/ruby
#coding:utf-8

['yaml', 'fileutils','./conf', 'caset'].each{|mod|require mod}
索引 = YAML.load File.read("#{$config}/path.yaml")

# [ABSTRACT.README.md](https://gitlab.ctbiyi.com/Frampt/caset/-/blob/master/lib/caset/gen_pytest.rb)

索引['pytest-unit'].each do|path|
  Caset::Pytest.gen(option = {
    path: path,
    head: "Atom_capacity",
    level: %w|fail pending|.map{|w|w.to_sym} # strict pending fail
  })
end

`mv tests/.datahouse tests/units`
`rm -rf tests/units/.datahouse`
`mv tests .tmp`

puts "WRAN:你需要手动移动.tmp/tests到项目文件中,移动前请检查测试文件内容."

__END__
#!/usr/bin/python3
import yaml

doc_paths = [
  # doc here
]
for doc_path in doc_paths:
  with open(doc_path,'r', encoding='utf8') as file:
    yaml.load(file.read())