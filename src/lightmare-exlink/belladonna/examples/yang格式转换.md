
# YANG格式转换

## 工具

### [pyang](https://github.com/mbj4668/pyang)

```shell
pip3 install pyang
```

### [pyangbind](https://github.com/robshakir/pyangbind)

```shell
pip3 install pyangbind
export PYBINDPLUGIN=`/usr/bin/env python3 -c 'import pyangbind; import os; print ("{}/plugin".format(os.path.dirname(pyangbind.__file__)))'`
echo $PYBINDPLUGIN

pyang --plugindir $PYBINDPLUGIN -f pybind -o binding.py tests/base-test.yang
```

## 格式转换

### YANG ==> YIN(netconf)

```shell
pyang -f yin DOCNAME.yang -o DOCNAME.yin
```

### YANG ==> tree

```shell
pyang -f tree DOCNAME.yang -o DOCNAME.tree
```

### YANG ==> swagger.json

OpenNetworkingFoundation:EagleUmlCommon工具不在主库,需要切换分支`ToolChain`

```shell
cd tools
git clone -b ToolChain https://github.com/OpenNetworkingFoundation/EagleUmlCommon.git
ls -l EagleUmlCommon/YangJsonTools/# swagger.py是插件
cd ..

# 生成swagger接口文件
pyang --plugindir ./EagleUmlCommon/YangJsonTools/ -f swagger -p ./models -o ./swagger.json ./models/device.yang --generate-rpc=False

# docker启动swagger-ui
# BASE_URL := WEB-API路径, SWAGGER_JSON := 容器中接口文档的路径, 其他参数参见DOCKERFILE
export EXPORTS=`echo $PWD`
docker run --name swagger-ui -d -p 80:8080 -e BASE_URL=/swagger -e SWAGGER_JSON=/swaggerfiles/swagger.json -v $EXPORTS:/swaggerfiles swaggerapi/swagger-ui
```

※ 转化swagger时出现依赖异常, 只需将缺少的yang模型放到目标同级目录下即可; 只要能生成API文档, 则表示模型转换一定完成

访问`http://localhost/swagger/`验证，如需更换接口文件则修改swaggerfiles/swagger.json对应宿主目录下的其他接口文件即可

### YANG ==> uml.png

```shell
apt install graphviz
wget https://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar

pyang -f uml DOCNAME.yang -o DOCNAME.uml
# an img/ folder will be created
java -jar plantuml.jar DOCNAME.uml # ==> DOCNAME.png
```

### RFC文件中提取YANG

```shell
git clone https://github.com/xym-tool/xym.git
cd xym/
python setup.py install

wget https://www.rfc-editor.org/rfc/rfc8299.txt
xym ../rfc8299.txt --dstdir ../
cd ../
mv ietf-l3vpn-svc@2018-01-19.yang ietf-l3vpn-svc.yang
```

其实留意文档的定义部分往往都有`<CODE BEGINS>`和`<CODE ENDS>`包裹，注意页眉页脚，可以很容易分离出代码文件
