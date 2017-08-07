## PHP生命周期

### SAPI层
```C
struct _sapi_module_struct {
char *name;
char *pretty_name;
int (*startup)(struct _sapi_module_struct *sapi_module);//舒适化调用
int (*shutdown)(struct _sapi_module_struct *sapi_module);//解释器关闭
int (*activate)(TSRMLS_D);//初始化每个请求的数据
int (*deactivate)(TSRMLS_D);//请求结束调用
int (*ub_write)(const char *str, unsigned int str_length TSRMLS_DC);//php会调用此函数将执行结果输出给client
void (*flush)(void *server_context);//刷新缓冲流，有内容则立刻输出
struct stat *(*get_stat)(TSRMLS_D);
void (*sapi_error)(int type, const char *error_msg, ...);//一般调用php_error，使用php内置的错误处理。
int (*header_handler)(sapi_header_struct *sapi_header,
sapi_headers_struct *sapi_headers TSRMLS_DC);//SAPI激活时，读取header内容
int (*send_headers)(sapi_headers_struct *sapi_headers TSRMLS_DC);发送所有heraders
void (*send_header)(sapi_header_struct *sapi_header,//发送的那个header给client
int (*read_post)(char *buffer, uint count_bytes TSRMLS_DC);//在SAPI激活的时候，将post数据放入$HTTP_RAW_POST_DATA 和 $_POST
char *(*read_cookies)(TSRMLS_D);//SAPI激活时，填充cookie至$_COOKIE
};
```

### php核心
当应用程序想要启动一个PHP解释器时，会调用php_module_startup，这个函数就像一个主开关一样开启PHP解释器。激活SAPI，初始化输出缓冲体系，开启zendVM，读取php.ini配置，为接受第一次请求PHP)做好准备。

以下列举出比较重要的几个步骤。
* php_module_startup  master startup for php
* php_startup_extensions  active all registered extensions
* php_output_startup  
* php_request_startup  请求之初执行，这是开始处理请求的总开关，调用SAPI的请求处理函数，激活ZEND对于每个请求的初始化，调用所有注册模块request_startup_func。
* php_init_config 读取ini配置并根据配置内容有相应的行为
* php_request_shutdown  请求结束，调用RSHUTDOWN
* php_end_ob_buffers  
* php_module_shutdown 关闭解释器


### PHP扩展
扩展可以被静态编译至PHP，也可以在ini中配置，在php_init_config解析阶段，会被注册。

对于一个可注册扩展，钩子会挂在其_`zend_module_entry`中,如下
```C
struct _zend_module_entry {
	unsigned short size;
	unsigned int zend_api;
	unsigned char zend_debug;
	unsigned char zts;
	const struct _zend_ini_entry *ini_entry;
	const struct _zend_module_dep *deps;
	const char *name;
	const struct _zend_function_entry *functions;
	int (*module_startup_func)(INIT_FUNC_ARGS);
	int (*module_shutdown_func)(SHUTDOWN_FUNC_ARGS);
	int (*request_startup_func)(INIT_FUNC_ARGS);
	int (*request_shutdown_func)(SHUTDOWN_FUNC_ARGS);
	void (*info_func)(ZEND_MODULE_INFO_FUNC_ARGS);
	const char *version;
	size_t globals_size;
#ifdef ZTS (是否开启线程安全)
	ts_rsrc_id* globals_id_ptr;
#else
	void* globals_ptr;
#endif
	void (*globals_ctor)(void *global TSRMLS_DC);
	void (*globals_dtor)(void *global TSRMLS_DC);
	int (*post_deactivate_func)(void);
	int module_started;
	unsigned char type;
	void *handle;
	int module_number;
	char *build_id;
};
```

几个比较重要的元素。
* module_startup_func 当模块第一次载入时，此`hook`被调用。注册全局变量，完成一次性初始化内容部分，初始化.ini配置中该模块的变量。
* module_shutdown_func  解释器关闭时调用，释放空间和资源。
* request_startup_func  请求开始时调用。
* request_shutdown_func 
* functions  扩展定义的函数
* 在配置文件中生命的函数


### Zend扩展
php请求最以后一个部分

zend Engine中主要使用的函数
* zend_compile
* zend_execute 执行zend_compile中生成的oparray
* zend_error_cb PHP中触发Error，会执行这个指针指向的函数。
* zend_fopen

```C
struct _zend_extension {
char *name;
char *version;
char *author;
char *URL;
char *copyright;
startup_func_t startup; //同 _zend_entry_module中的对应方法
shutdown_func_t shutdown;//同 _zend_entry_module中的对应方法
activate_func_t activate;//同 _zend_entry_module中的对应方法
deactivate_func_t deactivate;//同 _zend_entry_module中的对应方法
message_handler_func_t message_handler;//扩展注册时调用
op_array_handler_func_t op_array_handler;
statement_handler_func_t statement_handler;//debug可以使用
fcall_begin_handler_func_t fcall_begin_handler;//在opcode ZEND_DO_FCALL* 调用前执行
fcall_end_handler_func_t fcall_end_handler;//在opcode ZEND_DO_FCALL* 调用后执行
op_array_ctor_func_t op_array_ctor;
op_array_dtor_func_t op_array_dtor;
int (*api_no_check)(int api_no);
void *reserved2;
void *reserved3;
void *reserved4;
void *reserved5;
void *reserved6;
void *reserved7;
void *reserved8;
DL_HANDLE handle;
int resource_number;
};
```

### 上面列出的一大堆东西在apache mod_php5是如何运行的
---
#### StartUp阶段（开启解释阶段）
---
1. sapi_startup
2. php_module_startup
3. php_output_startup
4. zend_startup
5. parse_ini_values
6. startup_internal_extensions(静态编译)
7. startup_dynamically_loaded_extensions(ini中配置的动态扩展)
8. startup_zend_extensions

#### per request steps
---
1. php_request_startup 请求之初执行，这是开始处理请求的总开关，调用SAPI的请求处理函数，激活ZEND对于每个请求的初始化，调用所有注册模块request_startup_func。
2. php_output_active
3. zend_active initialize compiler and executor
4. sapi_active pull in request data from sapi
5. zend_activate_module
6. zend_compile（parse and execute the script）
7. zend_deactive
8. sapi_deactive
9. sapi_shutdown
10. zend_shutdown
