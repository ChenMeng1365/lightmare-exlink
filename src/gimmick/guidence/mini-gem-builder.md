
# 最简化版的gem.build模板

## 脚本化部署

```shell
# 生成Gemfile
bundle init

# 或者
cat <<EOF >> Gemfile
source "https://ruby-china.com"

gemspec

# 加入依赖
gem "rake",     "~> 12.0"
EOF

# Rakefile
cat <<EOF >> Rakefile
require "bundler/gem_tasks"
task :default => :spec
EOF

# 将关键源码拷入生成目录
rm -rf lib
mkdir lib
cp -rf XXX_PATH lib

# 编写gemspec
cat <<EOF >> XXX.gemspec
require_relative 'lib/XXX' # 关联入口

Gem::Specification.new do |spec|
  spec.name          = "XXX"
  spec.version       = XXX::VERSION
  spec.authors       = ["作者名"]
  spec.email         = ["作者邮箱@gmail.com"]
  spec.summary       = %q{gem摘要}
  spec.description   = %q{gem描述}
  spec.files         = ["XXX"].map{|f|"lib/#{f}.rb"} # 安排所有项目必要文件路径
  spec.require_paths = ["lib"] # 项目内容放lib目录下
end
EOF

# 项目XXX入口, 如项目本身有制作可不生成
cat <<EOF >> lib/XXX.rb
#coding:utf-8

# 以lib为根目录引入关联文件, 引用模块并不一定要维持module空间结构, 但能维持最好
[].each{|submod|require submod}

class XXX
  VERSION = '0.0.0'
end
EOF

# 生成gem
gem build XXX.gemspec
```

## lib目录最低结构要求

lib为根据gemspec成为根目录, 关联引用为lib/XXX.rb, 建议在此书写版本和所有内部关联引用, 以便一次性导入

```shell
lib
├── XXX
│   ├── SUB1
│   │   └── (...)
│   ├── (...)
│   └── SUBN
│       ├── SUBN1.rb
│       ├── (...)
│       └── SUBNN.rb
├── Others(...)
└── XXX.rb
```
