## crontab介绍
平常我们每天都会执行很多任务，人力执行自然很不爽，linux下的定时任务服务可以帮助我们解决这些。以下是我在使用中遇到的一些步骤和体会。(linux自带crontab服务)


## 开启服务
要想使用首先是开启电脑上的crontab服务(开没开启可以start一下嘛)
~~~
* /sbin/service crond start
* /sbin/service crond restart
* /sbin/service crond stop
* /sbin/service crond reload (可以重新加载配置)
~~~
要把cron设为在开机的时候自动启动，在 /etc/rc.d/rc.local 脚本中加入 /sbin/service crond start 即可

## 使用服务
crontab -e 编辑要加入crontab执行的命令，这时候会进入vi编辑，我们把要执行的命令加入即可

### 命令格式如下
~~~
10 20 * *  1 echo '' > /tmp/haha
~~~

| 分                   | 小时   | 日期   | 月份   | 星期x  | 要执行的命令 |
| ------------------- | ---- | ---- | ---- | ---- | ------ |
| */30 每三十分钟执行一次 0-59 | 0-23 | 1-31 | 1-12 | 1-7  | 要执行的命令 |

## 注意一些问题
在crontab -e 中写命令时，注意，在bashrc里写的alias别名是无法识别的，并且路径最好就写绝对路径。