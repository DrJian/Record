## 好用的命令

###展示当前 目录下各个子目录所占体积

```shell
du -sh *
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

### 进程管理

- pgrep 根据option查找相关匹配的进程信息 
> eg.1 pgrep -l -u work php
> 查找work账号下的php相关进程信息，这里是模糊查找，php-cgi这样的命令也会被找到，如果进行严格匹配，可以使用-x参数，由此看出，pgrep是根据command名去匹配相关的进程信息，同时我们可以加入各种限定
>
> eg.2 pgrep -l -x 'php.*'(pattern)
>
> 这里-x指令严格匹配，匹配后面的pattern，可以是正则

- pkill 根据option匹配相关的进程信息，同时可以发送signal信息

> eg.1 pkill -9 -u work -x php
>
> 发送 强制终止信息给work账号下的php命令开启的进程
>
> eg.2 pkill -HUP syslogd
>
> 让syslogd进程reload配置
>
> eg.3 pkill -HUP -u work nginx
>
> 让work账号下的nginx进程重新读取配置

### 任务切换

* jobs 列出后台执行的任务

  >eg.1 jobs -l 
  >
  >列出所有后台执行任务的全部信息，数字为进程Pid
  >
  >eg.2 jobs -r
  >
  >列出 执行中的任务，-s列出stop状态的任务
  >
  >eg.3 jobs -p  1 (这里的1是任务标识)
  >
  >只列出任务标识为1的任务的进程id pid
  >
  >eg.4 jobs -p | xargs kill -9 
  >
  >强制删除后台运行的所有任务

* bg

  > bg  任务标识号
  >
  > 令后台执行的任务恢复到running状态

* fg 

  > fg 任务标识号
  >
  > 令后台执行的任务切到前台执行

**ctrl-z将命令切到后台，会变成stop状态，在命令后+&，会将命令放到后台，但保持running状态**