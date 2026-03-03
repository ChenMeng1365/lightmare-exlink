
# SVN ProDeploy

将代码从开发环境向生产环境部署的一个缓冲, 通过脚本将备份和上传源码准备好

### 备份代码到本地

```shell
cat <<EOF > ./back.sh
rm -rf ~/workspace/dev/svn/PROJECT-NAME-$(date "+%Y%m%d%H")
svn co https://IP:PORT/PATH/PROJECT-NAME ~/workspace/dev/svn/PROJECT-NAME-$(date "+%Y%m%d%H")
EOF
chmod +x ./back.sh

~/workspace/dev/svn$ ./back.sh
```

删除当前时刻的本地仓库, 从远端拖一个新版本的仓库到本地  
一般以小时来区分不同仓库的版本  
可以放到crontab中定时备份远程仓库

```shell
# /etc/crontab
MIN HOUR DAY MONTH WEEKDAY USER $HOME/workspace/dev/svn/back.sh

~$ systemctl restart cron # or crond
```

### 周期性打包备份

```shell
cat <<EOF > ./tarpack.rb
#!/usr/local/bin/ruby
#coding:utf-8

whitelist = ['port','port.sh','push.sh','pull.sh','clear.sh','back.sh','README.md',"tarpack.rb",".tar.gz"]

Dir["*"].each do|path|
  next if whitelist.inject(false){|flag,spec|flag || path.include?(spec)}
  `tar zcvf #{path}.tar.gz #{path}`
end
EOF
chmod +x ./tarpack.rb

~/workspace/dev/svn$ ./tarpack.rb
```

对环境中所有代码进行打包  
制作一个白名单列表, 白名单的内容不打包(至少.tar.gz文件不再打包)

### 生成测试/提交环境

```shell
cat <<EOF > ./pull.sh
rm -rf ~/workspace/dev/svn/PROJECT-NAME-latest
svn co https://IP:PORT/PATH/PROJECT-NAME ~/workspace/dev/svn/PROJECT-NAME-latest
EOF
chmod +x ./pull.sh

~/workspace/dev/svn$ ./pull.sh
```

临时拖一个名为XXX-latest的仓库, 以最新状态提交改动  
改动的代码向这个仓库中合并

### 批量合并改动

```shell
cat <<EOF > ./push.sh
cp -rf port/LOCAL-MOD PROJECT-NAME-latest/SOME-FOLDER/
EOF
chmod +x ./push.sh

~/workspace/dev/svn$ ./push.sh
```

先从其他项目中将代码提交到本地port目录中, 保持其中目录结构和项目一致  
人工修改及确认后, 再合并到XXX-latest  

```shell
~/workspace/dev/svn$ cd ../XXX
~/workspace/dev/XXX$ ./port.sh
~/workspace/dev/XXX$ cd ../svn
~/workspace/dev/svn$ tree port/
~/workspace/dev/svn$ ./push.sh
```

关于从项目向svn环境中转移代码的脚本`port.sh`请根据项目内容自制, 位置既可以放项目内, 也可以放svn环境中

准备port前需先清空现有缓存`port`目录, 以避免混乱

```shell
cat <<EOF > ./clear.sh
rm -r port/*
EOF
chmod +x ./clear.sh

~/workspace/dev/svn$ ./clear.sh
```

### SVN检查提交

提交仍然使用svn内置命令, 提交前确认变更

```shell
~/workspace/dev/svn$ cd XXX-latest/XXX

# 检查改动 
# M:修改 A:增加 D:删除 I:忽略
# L:锁定 C:冲突 R:替换
# !:被非SVN方式删除
# ?:未入管的文件 X:未入管的目录
~/workspace/dev/svn/XXX-latest/XXX$ svn status

# 增加文件
~/workspace/dev/svn/XXX-latest/XXX$ svn add FILE

# 删除文件
~/workspace/dev/svn/XXX-latest/XXX$ svn del FILE

# 提交修改
~/workspace/dev/svn/XXX-latest/XXX$ svn commit -m "DESC"
```
