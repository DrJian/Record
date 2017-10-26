## 好用的命令

###展示当前 目录下各个子目录所占体积

```shell
find ./ -type d -depth 1 | xargs du -sh
```

### 大批量删除指定名称的文件

```shell
find ./ -type f -name "*.log" | xargs rm -f
```

###  查看进程信息

```shell
ps -aux | grep xxx
```

### 查看端口号占用

```shell
netstat -tlnap| grep 8500 
```

如果某个进程无owner，则去掉-p选项即可，否则需要root权限展示

## 进程管理

- pgrep 根据option查找相关匹配的进程信息 
> eg.1 pgrep -l -u work php
> 查找work账号下的php相关进程信息，这里是模糊查找，php-cgi这样的命令也会被找到，如果进行严格匹配，可以使用-x参数，由此看出，pgrep是根据command名去匹配相关的进程信息，同时我们可以加入各种限定

- pkill 根据option匹配相关的进程信息，同时可以发送signal信息

> eg.1 pkill -9 -u work -x php
>
> 发送 强制终止信息给work账号下的php命令开启的进程
>
> eg.2 pkill -HUP syslogd
>
> 让syslogd进程reload配置