#!/usr/bin/env ruby
features = ARGV + DATA.read.split("\n").map{|i|i.split(' ')}.flatten.uniq
paths = File.read("sup-doc-0926/ydk-models-cx600-v8r21-0.1.2-level1.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-cx600-v8r21-0.1.2-level2.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-cx600-v8r21-0.1.2-level3.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-0.1.1-level1.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-0.1.1-level2.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-0.1.1-level3.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-9000-e-50010-level1.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-9000-e-50010-level2.txt").split("\n")
# paths = File.read("sup-doc-0926/ydk-models-zte-9000-e-50010-level3.txt").split("\n")


selects = paths.select{|path|
  features.inject(true){|flag,feature|
    feat,logic = feature[0]=='-' ? [feature[1..-1],false] : [feature, true]
    flag&&(path.include?(feat)==logic)
  }
}
File.write "abscan-ydk.txt", selects.join("\n")

__END__
-operation -state