[TOC]

### Nginx配置指令的执行顺序。

nginx先读取http header，在nginx上查找与请求相关的虚拟主机的配置，找到对应的主机再执行对应操作。

1. `NGX_HTTP_POST_READ_PHASE`:
   接收完请求头之后的第一个阶段，它位于uri重写之前，实际上很少有模块会注册在该阶段，读取请求body阶段。
2. `NGX_HTTP_SERVER_REWRITE_PHASE`:
   server级别的uri重写阶段，也就是该阶段执行处于server块内，location块外的重写指令，前面的章节已经说明在读取请求头的过程中nginx会根据host及端口找到对应的虚拟主机配置；
3. `NGX_HTTP_FIND_CONFIG_PHASE`:
   寻找location配置阶段，该阶段使用重写之后的uri来查找对应的location，值得注意的是该阶段可能会被执行多次，因为也可能有location级别的重写指令；
4. `NGX_HTTP_REWRITE_PHASE`:
   location级别的uri重写阶段，该阶段执行location基本的重写指令，也可能会被执行多次；
5. `NGX_HTTP_POST_REWRITE_PHASE`:
   location级别重写的后一阶段，用来检查上阶段是否有uri重写，并根据结果跳转到合适的阶段；
6. `NGX_HTTP_PREACCESS_PHASE`:
   访问权限控制的前一阶段，该阶段在权限控制阶段之前，一般也用于访问控制，比如限制访问频率，链接数等；
7. `NGX_HTTP_ACCESS_PHASE`:
   访问权限控制阶段，比如基于ip黑白名单的权限控制，基于用户名密码的权限控制等；allow,deny等指令
8. `NGX_HTTP_POST_ACCESS_PHASE`:
   访问权限控制的后一阶段，该阶段根据权限控制阶段的执行结果进行相应处理；
9. `NGX_HTTP_TRY_FILES_PHASE`:
   try_files指令的处理阶段，如果没有配置try_files指令，则该阶段被跳过；
10. `NGX_HTTP_CONTENT_PHASE`:
  内容生成阶段，该阶段产生响应，并发送到客户端；
11. `NGX_HTTP_LOG_PHASE`:
    日志记录阶段，该阶段记录访问日志。

**分属两个不同处理阶段的配置指令之间是不能穿插着运行的。**

​	在内容产生阶段，为了给一个request产生正确的响应，nginx必须把这个request交给一个合适的content handler去处理。如果这个request对应的location在配置文件中被明确指定了一个content handler，那么nginx就可以通过对location的匹配，直接找到这个对应的handler，并把这个request交给这个content handler去处理。这样的配置指令包括像，perl，flv，proxy_pass，mp4

如果一个request对应的location并没有直接有配置的content handler，那么nginx依次尝试:

1. 如果一个location里面有配置 random_index on，那么随机选择一个文件，发送给客户端。
2. 如果一个location里面有配置 index指令，那么发送index指令指明的文件，给客户端。
3. 如果一个location里面有配置 autoindex on，那么就发送请求地址对应的服务端路径下的文件列表给客户端。
4. 如果这个request对应的location上有设置gzip_static on，那么就查找是否有对应的.gz文件存在，有的话，就发送这个给客户端（客户端支持gzip的情况下）。
5. 请求的URI如果对应一个静态文件，static module就发送静态文件的内容到客户端。

​        内容产生阶段完成以后，生成的输出会被传递到filter模块去进行处理。filter模块也是与location相关的。所有的fiter模块都被组织成一条链。输出会依次穿越所有的filter，直到有一个filter模块的返回值表明已经处理完成。

这里列举几个常见的filter模块，例如：

1. server-side includes。
2. XSLT filtering。
3. 图像缩放之类的。
4. gzip压缩。

在所有的filter中，有几个filter模块需要关注一下。按照调用的顺序依次说明如下：

| filter模块  |                    作用                    |
| :-------: | :--------------------------------------: |
|  write：   |       写输出到客户端，实际上是写到连接对应的socket上。        |
| postpone: |     这个filter是负责subrequest的，也就是子请求的。      |
|   copy:   | 将一些需要复制的buf(文件或者内存)重新复制一份然后交给剩余的body filter处理。 |