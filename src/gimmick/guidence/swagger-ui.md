
# swagger-ui

* 使用docker启动swagger-ui
* 使用项目文件夹为根目录,`.tmp`作为基础路径挂载到容器的`/swaggerfiles`, swagger-ui需要关联`/swaggerfiles/swagger.json`

```shell
cat <<EOF > .script/swagger-ui-start.sh
export EXPORTS=\`echo \$PWD\`
docker run --name swagger -d -p 80:8080 -e BASE_URL=/swagger -e SWAGGER_JSON=/swaggerfiles/swagger.json -v \$EXPORTS/.tmp:/swaggerfiles swaggerapi/swagger-ui
EOF
chmod +x .script/swagger-ui-start.sh
```

* 使用docker关闭swagger-ui
  
```shell
cat <<EOF > .script/swagger-ui-shutdown.sh
docker stop swagger
docker rm swagger
EOF
chmod +x .script/swagger-ui-shutdown.sh
```
