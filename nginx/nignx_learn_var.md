## nginx学习笔记
以下学习参考[agentzh(章亦春)的nginx教程](https://openresty.org/download/agentzh-nginx-tutorials-zhcn.html)以及google老师，以及[淘宝核心系统服务器平台组](http://tengine.taobao.org/book/index.html)

### set
---
```nginx
location /hi{
	set $a "hi";
	return 200  "hello";
}
```

* 这里的set $a会创建一个变量，并赋值为`hi`，注意的是，nignx启动时，变量已创建，但是在具体运行到这里后变量值才被赋值，也就是说，创建和赋值是分开的。
* nignx变量名的可见范围是整个配置，但是不同的请求之间是彼此隔离的，变量的声明周期与请求相关，与location无关。(这里可以联想变成语言中，全局变量可以在各个函数体中被引用，但是如果分开执行两次，彼此是隔离的)


### 内建变量
---
nginx有很多内建的变量群，需要注意，在 `$arg_xxx`中，可以获取名为xxx的请求参数，并且自动将所有get的参数转为小写之后进行匹配。

```nginx
location /hi{
   add_header oriuri $uri;
	add_header requri $request_uri;
	add_header post $arg_post;
	return 301 "www.baidu.com";
    }
```
```bash
curl hongjian.cn/hi?post=helloworld -v
< HTTP/1.1 301 Moved Permanently
< Server: nginx
< Date: Sun, 23 Apr 2017 10:10:12 GMT
< Content-Type: text/html
< Content-Length: 178
< Connection: keep-alive
< Location: www.baidu.com
< oriuri: /hi
< requri: /hi?post=helloworld
< post: helloworld

```


类似 $arg_XXX 的内建变量还有不少，比如用来取 cookie 值的 $cookie_XXX 变量群，用来取请求头的 $http_XXX 变量群，以及用来取响应头的 $sent_http_XXX 变量群。这里就不一一介绍了，感兴趣可以参考 [ngx_http_core](http://nginx.org/en/docs/http/ngx_http_core_module.html) 模块的官方文档。

**大部分内建变量都只是可读的，如果去赋值，会在启动nginx时报错**

### 取处理与存处理
---
不是所有的 Nginx 变量都拥有存放值的容器。`拥有值容器`的变量在 Nginx 核心中被称为“被索引的”（indexed）；反之，则被称为“未索引的”（non-indexed）。`$arg_xxx`就是未索引的变量。

在我们读取类似 `$arg_xxx` 内建变量群时，nginx会执行相应的读处理程序扫描URL的参数串去获取这个变量的值，`$cookie_xxx`也是这样的.

### nginx值容器缓存
---
```nginx
http{
	map $arg_method $ret {
	    GET 1;
	    POST 2;
	    PUT 3;
	    DELETE 4;
	    default 5;
	}
	server {
		location /hi {
        #set $arg_method get;
        return 200 "ret:$ret";
	}
}
```

这里我们使用了一个nginx中的map映射规则。这个map只能卸载http模块中，所以也就是全局的了。这里我们看一下请求情况

```bash
curl hongjian.cn/hi\?method=post
ret:2

curl hongjian.cn/hi\?method=POST
ret:2
```
这里我们可以看到，请求参数中的method，会按照map中的规则，映射为对应值，并且nginx会将参数转成小写后进行比较。

注意到上面的set语句是被注释掉的，这里我们将注释打开后，再次访问。

```bash
curl hongjian.cn/hi\?method=POST
ret:1
```
返回值变成了1，那这里就印证了一个事实，在取值(取ret)时，才会进行计算，这里我们称这种现象为`惰性计算`。这里还看不到和缓存有什么关系，我们再做一个小调整。

```nginx
http{
	map $arg_method $ret {
	    GET 1;
	    POST 2;
	    PUT 3;
	    DELETE 4;
	    default 5;
	}
	server {
		location /hi {
        set $ret1 $ret;
        set $arg_method default;
        set $ret2 $ret;
        return 200 "ret1:$ret, ret2:$ret2";
	}
}
```
访问一下，查看请求结果

```bash
curl hongjian.cn/hi\?method=post
ret1:2, ret2:2
```

`ret2`并没有因为我们将method变量设置为default而变化，这是为什么呢？原来，nginx可以为创建的变量选择值容器来作为缓存，ngx_map这种结构被认定计算耗费大，所以会进行缓存，因为惰性计算，只有在第一次执行对`ret`的取程序时，才会计算ret的map结果，并将这个值作为缓存，所以之后我们就算修改了`method`的值，下一条语句执行取程序时，还会返回上次缓存的结果。`缓存值容器的声明周期是和请求相关联的`

所以这种全局性的map结构，只有一个请求的第一次取程序执行时才会被计算一次，之后执行取程序时，会使用缓存结果。

#### 主动计算也很常见
比如`set`赋值操作就会进行即时计算并将结果赋值给变量。

### 关于父子请求
---
这里说的子请求并不是真正意义上的一个子HTTP请求，而是借助第三方模块，比如ngx_location发起的一个C语言的调用而已，父子请求间对于变量有共享也有非共享的，遇到之后再作具体查询和分析。


部分内建变量只作用于主请求，大部分作用于当前请求。父子请求之间共享变量并不是一个好事情。

### Nginx变量类型
---
Nginx 变量的值只有一种类型，那就是字符串，但是变量也有可能压根就不存在有意义的值。没有值的变量也有两种特殊的值：一种是“不合法”（invalid），另一种是“没找到”（not found）。当 Nginx 用户变量 $foo 创建了却未被赋值时，$foo 的值便是“不合法”；而如果当前请求的 URL 参数串中并没有提及 XXX 这个参数，则 $arg_XXX 内建变量的值便是“没找到”。

只有“不合法”这个特殊值才会触发 Nginx 调用变量的“取处理程序”，而特殊值“没找到”却不会。


### content阶段
---
一个 location 中使用 content 阶段指令时，通常情况下就是对应的 Nginx 模块注册该 location 中的“内容处理程序”。当一个 location 中未使用任何 content 阶段的指令，即没有模块注册“内容处理程序”时，把当前请求的 URI 映射到文件系统的静态资源服务模块。

#### content阶段一般有三种静态资源服务模块
---
`nginx_autoindex`和`nginx_index模块会`