## 数据流重定向
* 基础概念：

|华丽分割|stdin(输入)|stdout(正确输出)|stderr(错误输出)|
|:----:|:----:|:----:|:----:|
|对应数据值|0|1|2|

可以将原本打到屏幕上的数据输出到指定的地方，比如可以将根目录下的文件放到当前目录下
~~~
ll -a / > ./rootfile
~~~

* \> 和 >>区别在于前者是覆盖原有内容，后者是在原有内容的基础上追加

* /dev/null 垃圾桶黑洞设备，有一些产生之后对我们没用的垃圾信息，我们可以将数据流重定向到 /dev/null这;比较典型的例子，就是我们执行一些定时任务，本身已经打出错误日志等，所以不需要再获取错误信息。例子如下：

~~~
php auto_add_pv.php >/dev/null 2>&1 
~~~

这里的话是将可能会出错的信息，输出到标准输出1所输出的位置

* 上面说完输出，我们再来看看输入 < 以及 <<,前者为从其他数据源输入文件内容到指定文件，<<指定输入结束符，我们可以在键盘上输入我们想输入的内容，并结束输入

~~~
cat >taskfile << 1;//输入1后，便会停止输入
cat > taskFile < srcFile;//源文件内容输入目标文件中
~~~

## 命令执行次序
* ;依次执行 cd a && cd b
* &&与执行 a && b   a执行后得到的$?的返回值为0，则执行b
* ||或执行 q || b   a执行后得到的$?返回值为0，则不执行b，如果a执行错误，才执行b

## 管道命令（|）
前一个命令的输出作为下一个命令的输入，有许多经典的搭配,例如：
grep:
~~~
ll / | grep home
~~~
wc -l 列出行
~~~
cat /etc/man.config | wc -l
~~~

<link rel="stylesheet" href="D:\imp\github\highlight.js\src\styles\darcula.css">
<script src="D:\imp\github\highlight.js\src\highlight.js"></script>
<script src="http://yandex.st/highlightjs/8.0/highlight.min.js"></script>
<script src="http://lib.sinaapp.com/js/jquery/1.9.1/jquery-1.9.1.min.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
