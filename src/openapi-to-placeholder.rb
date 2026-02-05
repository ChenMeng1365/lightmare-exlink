#!/usr/local/bin/ruby
#coding:utf-8
$:<<'.'
require 'neatjson'
require 'lib/xml-cache'
require 'lightmare-exlink/xiaolong/xtree'

Dir.mkdir '../tmp' unless File.exist? '../tmp'

begin # northbound
  source = '.'
  Dir["#{source}/*swagger*.yaml"].each do|modelpath|
    begin
      pool = XiaoLong::Northbound.build_from modelpath
      newpath = modelpath.gsub(".yaml",".json").gsub("#{source}/","../tmp/placeholder-")
      head = modelpath.include?('qos_') ? pool.find{|n|n.name=='qos'} : pool.first
      doc = pool.empty? ? "" : JSON.pretty_generate({head.name=>head.to_doc})
      File.write newpath, doc
    rescue => exception
      puts "#{modelpath}: #{exception.message}"
    end
  end
end

begin # southbound
  source = "."
  Dir["#{source}/*zxr*.json"].each do|modelpath|
    begin
      pool = XiaoLong::Southbound.build_from modelpath
      newpath = modelpath.gsub("#{source}/",'../tmp/placeholder-').gsub('huawei-','hw-ne5000-v8r11-')
      conf = []
      nodes = pool.select{|node|['configuration_schema'].include?(node.name)} # zte
      # nodes = pool # huawei
      nodes.each do|node|
        conf << {node.name=>node.to_doc}
      end
      doc = JSON.pretty_generate(conf)
      File.write newpath, doc
    rescue => exception
      puts "ERROR: #{modelpath}: #{exception.message}"
    end
  end
end

__END__


# nb
cp /home/leoma/workspace/dev/docs/openapi-bgp_swagger.yaml .
cp /home/leoma/workspace/dev/docs/openapi-qos-swagger_20211124_qosv2.yaml .

# sb zte
cp /home/leoma/workspace/doc/openapi-json-zte-m6000-v50010/zxr10-bgp@2021-03-02.json .
cp /home/leoma/workspace/doc/openapi-json-zte-m6000-v50010/zxr10-qos@2021-04-22.json .

# sb huawei
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-qos-bd@2020-06-11.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-qos-board@2020-06-11.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-qos-l3vpn@2020-02-27.json .
# sb huawei qos ref to ???
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-ifm-fr@2019-12-25.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-ifm-hdlc@2019-12-22.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-ifm-trunk@2020-02-14.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-ifm@2020-06-10.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-network-instance@2020-03-10.json .
cp ../../../doc/openapi-json-hw-ne5000-v8r11/huawei-acl@2020-02-20.json .