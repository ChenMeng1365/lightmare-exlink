#!/usr/local/bin/ruby
#coding:utf-8
$LOAD_PATH<<'.'
require 'neatjson'
require 'lib/xml-cache'
require 'lightmare-exlink/xiaolong/xtree'

Dir.mkdir '../tmp' unless File.exist? '../tmp'

#### QoS ######################################################################################################

#### 南向 

begin # 导入模板
  sdoc_path = "/home/leoma/workspace/doc"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-hw-ne5000-v8r11/huawei-qos.json"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-hw-ne40-v8r12/huawei-qos.json"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-hw-ne40-v8r22/huawei-qos@2020-06-11.json"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-zte-m6000-v50010/zxr10-qos@2021-04-22.json"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-zte-t8000-v40010/zxr10-qos@2021-04-22.json"
  # sdoc_tmpl = "#{sdoc_path}/openapi-json-zte-m6000-v50010/zxr10-bgp@2021-03-02.json"
  sdoc_tmpl = "#{sdoc_path}/openapi-json-hw-ne40-v8r22/huawei-ifm@2021-10-11.json"

  spool = []
  # sdoc_tmpl << "#{sdoc_path}/openapi-json-hw-ne40-v8r12/huawei-bgp-common-multiprotocol.json"
  # sdoc_tmpl << "#{sdoc_path}/openapi-json-hw-ne40-v8r12/huawei-bgp-common.json"
  # sdoc_tmpl << "./openapi-json-hw-ifm@2021-10-11.json"
  [sdoc_tmpl].each do|sdoc|
    spool += (XiaoLong::Southbound.build_from sdoc)
  end
  # sroot = spool.first
end

begin # 生成索引
  list = []
  # spool = spool.select{|n|n.name.include?('qos_schema')} if sdoc_tmpl.include?('zte')
  spool.each do|node|
    node.to_index(list)
    list << {}
  end
  # special find
  # list = list.select{|i|i.to_s.include?('public-as-only')}
  File.write "index-for-ifm-sb-ne40-v8r22.rb","[\n"+list.join(",\n")+"\n]"
  # File.write "native-index-for-qos-sb-m6000.rb","[\n"+list.join(",\n")+"\n]"
end

# begin # 查询节点
#   path = '#/definitions/qos/configuration/qos-template/diffserv-domains/*/behavior-aggregations/*'
#   node = sroot.trace path.gsub("#/definitions/",'').sub(sroot.name,"")
#   puts node.insight(:doc).last
# end

# begin # 实例拼装
#   groot = XiaoLong.gen_root
#   [
# 
#   ].each do|item|
#     path, val = item.keys.first, item.values.first
#     current = XiaoLong.asym path.sub('#/definitions/bgp/',''), groot
#     current.val = val
#   end
#   File.write "mock-qos-merge.json",JSON.pretty_generate(groot.to_doc(lambda{|n|n.val}))
# end

#### BGP ######################################################################################################

#### 北向 

# begin # 导入模板
#   ndoc_path = "/home/leoma/workspace/dev/docs"
#   ndoc_tmpl = File.read("#{ndoc_path}/openapi-bgp_swagger.yaml")
#   # ndoc_tmpl = File.read("#{ndoc_path}/openapi-qos_swagger.yaml")
#   # ndoc_tmpl = File.read("#{ndoc_path}/openapi-qos-swagger_20211124_qosv2.yaml")
#   nroot = (XiaoLong::Northbound.build ndoc_tmpl).find{|n|n.name=='bgp'}
# end

# begin # 生成索引
#   list = []
#   nroot.to_index(list)
#   File.write "index-for-bgp-nb.rb","[\n"+list.join(",\n")+"\n]"
# end

# begin # 查询节点
#   path = '#/definitions/bgp/configuration/instances/*/afs/*/sync-enable'
#   node = nroot.trace path.gsub("#/definitions/",'').sub(nroot.name,"")
#   puts node.insight(:doc).last
# end

# begin # 实例拼装
#   groot = XiaoLong.gen_root
#   [
#     {"#/definitions/bgp/configuration/instances/*[1]/afs/*[1]/af-type"=>"ipv4uni"},
#     {"#/definitions/bgp/configuration/instances/*[1]/afs/*[1]/route-export/networks-ipv4/*[1]/ipv4-prefix"=>"203.110.234.15/32"},
#     {"#/definitions/bgp/configuration/instances/*[1]/afs/*[1]/route-export/networks-ipv4/*[1]/route-policy"=>"rp_bgp_SetCommCN2_out"}
#   ].each do|item|
#     path, val = item.keys.first, item.values.first
#     current = XiaoLong.asym path.sub('#/definitions/bgp/',''), groot
#     current.val = val
#   end
#   File.write "mock-bgp-merge.json",JSON.pretty_generate(groot.to_doc(lambda{|n|n.val}))
# end

__END__

