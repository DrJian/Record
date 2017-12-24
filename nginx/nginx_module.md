## 模块配置

Nginx配置作用域：main，server，location，三种作用域。每个作用域的配置信息各需要使用一个数据结构去存储。

对于模块配置信息的定义，命名习惯是ngx_http_<module name>_(main|srv|loc)_conf_t。(保持与源代码类似)