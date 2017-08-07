## PHP生命周期
### CLI/CGI模式
---

### 开始前
* 初始化全局变量，赋值null一般
* 初始化常量，配置文件，比如php_version.h,config.win32.h
* 禁用函数和类，并将禁用信息存在compiler_globals（_zend_compiler_globals）的全局变量中
* 初始化Zend引擎和核心组件，注册内置函数，注册GLOBALS全局变量，解析php源文件，内存管理初始化等。
* 读取ini配置(php.ini,以及在编译php时指定的扫描路径--with-config-file-scan-dir,或者指定--with-config-file-path)
* 激活Zend(初始化变量表，编译器)，激活SAPI（sapi_activate，读取Http POST，Cookie内容，解析Header，填充$_SERVER，并填充），环境初始化(对POST，Cookie数据进行相关解析)，调用SAPI模块
### 开始
---
开始阶段分两个过程：
*  **MINIT(模块初始化阶段)，生命周期内仅执行一次**
*  **RINIT(模块激活阶段),此过程发生在该过程发生在请求阶段， 例如通过url请求某个页面，则在每次请求之前都会进行模块激活（RINIT请求开始）。**
---
#### MINIT
对于PHP注册的扩展模块，在MINIT阶段会回调所有的MINIT函数，在这个阶段可以做一些初始化工作，如注册常量，定义模块使用类等。扩展模块可以使用如下宏编写MINIT阶段的回调函数。(常驻内存)

```C
PHP_MINIT_FUNCTION(your extension name) {
	//注册常量或者类初始化
	return SUCCESS;
}
```
---
#### RINIT
当请求到达之后，PHP开始初始化执行脚本的基本环境，比如创建一个执行环境，保存PHP运行过程中的变量名称和值内容的符号表，以及当前所有的函数以及类信息的符号表。PHP会调用所有模块的RINIT函数，各模块可以通过如下宏执行相关操作。
```C
PHP_RINIT_FUNCTION(your extension name) {
	//例如记录请求开始时间
	return SUCCESS;
}
```
### 结束阶段
---
#### RSHUTDOWN 和 MSHUTDOWN
当一次请求执行结束后，执行RSHUTDOWN命令，当PHP进程退出时，触发MSHUTDOWN
相关宏调用如下

```C
PHP_RSHUTDOWN_FUNCTION(your extension name) {
	//例如记录请求结束时间
	return SUCCESS;
}

PHP_MSHUTDOWN_FUNCTION(your extension name) {
	//释放相关内存资源
	return SUCCESS;
}
```

![](http://www.walu.cc/phpbook/image/01fig01.jpg)
### 多进程模式
---
例如在PHP-FPM中每一个进程都会单独执行CGI下的模式
![](http://www.walu.cc/phpbook/image/01fig02.jpg)
### 多线程模式
---
![](http://www.walu.cc/phpbook/image/01fig04.jpg)
### 嵌入式
在.exe中可以调用PHP/ZE提供的函数

---
### 关于线程安全与不安全
---
最初PHP在进程模式下运行，不存在安全问题，当出现了多线程模式，进程的全局变量就会存在线程安全问题，为此，php内核推出新的抽象层(TSRM:Thread Safe Resource Management)。正常的PHP构建默认是关闭线程安全的，只有在被构建的sapi明确需要线程安全或线程安全在./configure enable-maintainer-zts阶段显式的打开时，才会以线程安全方式构建。 

## PHP变量在内核中的实现

核心数据结构 

```C
typedef union _zvalue_value {
	long lval;					/* long value */
	double dval;				/* double value */
	struct {
		char *val;
		int len;
	} str;
	HashTable *ht;				/* hash table value */
	zend_object_value obj;
} zvalue_value;
```
```C
struct _zval_struct {
	/* Variable information */
	zvalue_value value;		/* value */
	zend_uint refcount__gc;
	zend_uchar type;	/* active type 标记value类型*/
	zend_uchar is_ref__gc;
};
```

有了以上数据结构后，PHP实现了8种数据类型
* IS_NULL(未初始状态下的默认值),
* IS_BOOL(true or false)
* IS_LONG(signed long)
*  IS_DOUBLE(signed double)
*  IS_STRING(由于PHP内核zval的数据类型存储了字符串的长度，所以php可以在字符串中写入'\0'这个字符，因此PHP是二进制安全的), 
*  IS_ARRAY  在C语言中，一个数组只能承载一种类型的数据，而PHP语言中的数组则灵活的多， 它可以承载任意类型的数据，这一切都是HashTable的功劳， 每个HashTable中的元素都有两部分组成：索引与值， 每个元素的值都是一个独立的zval（确切的说应该是指向某个zval的指针）
*  IS_OBJECT
*  IS_RESOURCE（其实是个long,标记资源句柄）

上面zvalue_value中的type便是上面八种常量之一。

所以当我们需要确认一个参数的类型时，可以对type进行判断，这里不要直接去判断type的类型，调用Z_TYPE_P()的宏来实现，避免之后底层修改，无法通过type进行判断。

通常以_P结尾的宏参数对应一个 `zval *`,Z_TYPE()参数为zval 所以取值宏Z_TYPE_PP()的参数为`zval **`之后对于具体的的zval类型，宏分别为`Z_BVAL_xxx`(IS_BOOL), `Z_DVAL_xxx`(IS_DOUBLE), `Z_STRVAL_xx`(zval 中str.char*对应的部分)，`Z_STRLEN_xxx`(zval str.len部分)， `Z_ARRVAL_xx`(zval.ht),相关操作的宏都定义在`/Zend/zend_operator.h`中

#### 创建一个PHP变量吧
---
已经有了底层数据结构，如何创建一个php变量呢，申请一块内存，并让zval*类型的指针指向这块内存，当然这里申请内存的时候我们使用相关内核提供的宏，MAKE_STD_ZVAL(pzv),ALLOC_INIT_ZVAL()宏函数也是用来干这件事的， 唯一的不同便是它会将pzv所指的zval的类型设置为IS_NULL.

使用相关宏可以对创建的变量进行赋值，例如
* ZVAL_BOOL(pzv, b);（将pzv所指的zval设置为IS_BOOL类型，值是b);
* ZVAL_LONG(pzv, l); (将pzv所指的zval设置为IS_LONG类型，值是l);
* ZVAL_STRINGL(pzv,str,len,dup);
* ZVAL_STRING(pzv, str, dup);
* ZVAL_RESOURCE(pzv, res);
* ZVAL_DOUBLE(pzv, d);


#### 变量的存储方式
---
用户在PHP中定义的变量我们都可以在一个HashTable中找到， 当PHP中定义了一个变量，内核会自动的把它的信息储存到一个用HashTable实现的符号表里。

全局作用域的符号表是在调用扩展的RINIT方法(一般都是MINIT方法里)前创建的，并在RSHUTDOWN方法执行后自动销毁。

当用户在PHP中调用一个函数或者类的方法时，内核会创建一个新的符号表并激活之， 这也就是为什么我们无法在函数中使用在函数外定义的变量的原因 （因为它们分属两个符号表，一个当前作用域的，一个全局作用域的）。 如果不是在一个函数里，则全局作用域的符号表处于激活状态。

在zend的全局变量_zend_executor_globals结构体中
```C
HashTable *active_symbol_table;
HashTable symbol_table;		/* main symbol table */
```
上面symbol_table为全局变量符号表，active_symbol_table则为当前符号表

```PHP
<?php
$foo = 'bar';
?>
```
对应的操作如下

```C
zval *fooval;
MAKE_STD_ZVAL(fooval);
ZVAL_STRING(fooval, "bar", 1);
ZEND_SET_SYMBOL( EG(active_symbol_table) ,  "foo" , fooval);
```

#### 关于宏的问题，查看Zend/zend_global_macros.h  main/php_globals.h   main/SAPI.h
---
简单提一下
SG宏主要用于获取SAPI层范围内的全局变量 ,在SAPI
```C
#ifdef ZTS
# define SG(v) TSRMG(sapi_globals_id, sapi_globals_struct *, v)
SAPI_API extern int sapi_globals_id;
#else
# define SG(v) (sapi_globals.v)
extern SAPI_API sapi_globals_struct sapi_globals;
#endif

/*main/SAPI.c*/
#ifdef ZTS
SAPI_API int sapi_globals_id;
#else
sapi_globals_struct sapi_globals;
#endif
```

CG()宏可以获取zend编译时存储的数据结构，EG()宏可以获取zend执行时的全局变量
```C
/* Compiler */
#ifdef ZTS
# define CG(v) TSRMG(compiler_globals_id, zend_compiler_globals *, v)
int zendparse(void *compiler_globals);
#else
# define CG(v) (compiler_globals.v)
extern ZEND_API struct _zend_compiler_globals compiler_globals;
int zendparse(void);
#endif


/* Executor */
#ifdef ZTS
# define EG(v) TSRMG(executor_globals_id, zend_executor_globals *, v)
#else
# define EG(v) (executor_globals.v)
extern ZEND_API zend_executor_globals executor_globals;
#endif

```
PG宏 php运行时的核心数据结构
```C
#ifdef ZTS
# define PG(v) TSRMG(core_globals_id, php_core_globals *, v)
extern PHPAPI int core_globals_id;
#else
# define PG(v) (core_globals.v)
extern ZEND_API struct _php_core_globals core_globals;
#endif
```
//todo
php_core_globals的分析


![](http://images.cnitblog.com/blog2015/444975/201503/091012060652318.png)
#### 类

```C
struct _zend_class_entry {
	char type;
	char *name;
	zend_uint name_length;
	struct _zend_class_entry *parent;
	int refcount;
	zend_bool constants_updated;
	zend_uint ce_flags;

	HashTable function_table;
	HashTable default_properties;
	HashTable properties_info;
	HashTable default_static_members;
	HashTable *static_members;
	HashTable constants_table;
	const struct _zend_function_entry *builtin_functions;

	union _zend_function *constructor;
	union _zend_function *destructor;
	union _zend_function *clone;
	union _zend_function *__get;
	union _zend_function *__set;
	union _zend_function *__unset;
	union _zend_function *__isset;
	union _zend_function *__call;
	union _zend_function *__callstatic;
	union _zend_function *__tostring;
	union _zend_function *serialize_func;
	union _zend_function *unserialize_func;

	zend_class_iterator_funcs iterator_funcs;

	/* handlers */
	zend_object_value (*create_object)(zend_class_entry *class_type TSRMLS_DC);
	zend_object_iterator *(*get_iterator)(zend_class_entry *ce, zval *object, int by_ref TSRMLS_DC);
	int (*interface_gets_implemented)(zend_class_entry *iface, zend_class_entry *class_type TSRMLS_DC); /* a class implements this interface */
	union _zend_function *(*get_static_method)(zend_class_entry *ce, char* method, int method_len TSRMLS_DC);

	/* serializer callbacks */
	int (*serialize)(zval *object, unsigned char **buffer, zend_uint *buf_len, zend_serialize_data *data TSRMLS_DC);
	int (*unserialize)(zval **object, zend_class_entry *ce, const unsigned char *buf, zend_uint buf_len, zend_unserialize_data *data TSRMLS_DC);

	zend_class_entry **interfaces;
	zend_uint num_interfaces;

	char *filename;
	zend_uint line_start;
	zend_uint line_end;
	char *doc_comment;
	zend_uint doc_comment_len;

	struct _zend_module_entry *module;
};
```
#### 对象
```C
typedef struct _zend_object_value {
    zend_object_handle handle;  //  unsigned int类型，EG(objects_store).object_buckets的索引
    zend_object_handlers *handlers; //
} zend_object_value;
```


#### 变量的检索
---
例子
```C
{
    zval **fooval;
 
    if (zend_hash_find(
            EG(active_symbol_table(当前活跃符号表)), //这个参数是地址，如果我们操作全局作用域，则需要&EG(symbol_table)
            "foo",
            sizeof("foo"),
            (void**)&fooval
        ) == SUCCESS
    )
    {
        php_printf("成功发现$foo!");
    }
    else
    {
        php_printf("当前作用域下无法发现$foo.");
    }
}       
```

#### 类型转换
---
convert_to_*()函数
```C
//其它基本的类型转换函数
ZEND_API void convert_to_long(zval *op);
ZEND_API void convert_to_double(zval *op);
ZEND_API void convert_to_null(zval *op);
ZEND_API void convert_to_boolean(zval *op);
ZEND_API void convert_to_array(zval *op);
ZEND_API void convert_to_object(zval *op);
 
ZEND_API void _convert_to_string(zval *op ZEND_FILE_LINE_DC);
```

### zend内存管理
----
我们可以使用zend虚拟机提供的内存管理机制，在请求结束后，zendMM会回收内存，当然如果这个变量在请求之后依然会存在，并且在其他请求中会使用，那么我们选择使用传统的内存管理，malloc等函数。针对传统的malloc,free，ZendMM提供了emalloc,efree,pemalloc,pefree，其中pe前缀的是针对不确定是否永久分配，需要在运行时才可以进行确定的内存分配。如果运行时发现不是永久的，则映射为响应的efunction，反之则映射为相应pefunction。

#### 关于引用计数
---
```PHP
$x = 1;
$v= $x;
unset($x);
```
关于上面的程序，当我们在符号表中找到x之后，变量x从符号表中被去除，x的值对应一个指向其数据的zval*，发现zval*指向的zval的refcount_gc的值是2，所以将此zval的ref_count的值--成为1。

#### 写时复制机制
---
```PHP
$a = 1;
$b = $a;
%b += 5;
var_dump($a);// output 1
var_dump($b);// output 6
```
上面这种情况中，$a赋值给$b，之后$b += 5,如果后面我们要继续使用$a，会发生什么呢？结果分别是1和6，在PHP内核宏到底发生了什么呢？
```C
zval *get_var_and_separate(char *varname, int varname_len TSRMLS_DC)
{
    zval **varval, *varcopy;
    if (zend_hash_find(EG(active_symbol_table),varname, varname_len + 1, (void**)&varval) == FAILURE)
    {
        /* 如果在符号表里找不到这个变量则直接return */
        return NULL;
    }
 
    if ((*varval)->refcount < 2)
    {   
        //如果这个变量的zval部分的refcount小于2，代表没有别的变量在用，return
        return *varval;
    }
     
    /* 否则，复制一份zval*的值 */
    MAKE_STD_ZVAL(varcopy);
    varcopy = *varval;
     
    /* 复制任何在zval*内已分配的结构*/
    zval_copy_ctor(varcopy);
 
    /* 从符号表中删除原来的变量
     * 这将减少该过程中varval的refcount的值
     */
    zend_hash_del(EG(active_symbol_table), varname, varname_len + 1);
 
    /* 初始化新的zval的refcount，并在符号表中重新添加此变量信息，并将其值与我们的新zval相关联。*/
    varcopy->refcount = 1;
    varcopy->is_ref = 0;
    zend_hash_add(EG(active_symbol_table), varname, varname_len + 1,&varcopy, sizeof(zval*), NULL);
     
    /* 返回新zval的地址 */
    return varcopy;
}       
```
PHP-5.3中的函数
foreach($ar ras &$v){}使用之后不unset($v)，是一个出坑的地方
```C
static inline zval* zend_assign_to_variable(zval **variable_ptr_ptr(左边 =), zval *value(=右边), int is_tmp_var TSRMLS_DC)
{
	zval *variable_ptr = *variable_ptr_ptr;
	zval garbage;
	...针对数据和未正常初始化的处理
if (Z_TYPE_P(variable_ptr) == IS_OBJECT && Z_OBJ_HANDLER_P(variable_ptr, set)) {//针对对象类型处理
		Z_OBJ_HANDLER_P(variable_ptr, set)(variable_ptr_ptr, value TSRMLS_CC);
		return variable_ptr;
	}

 	if (PZVAL_IS_REF(variable_ptr)) {如果被赋值变量(左操作数)为一个引用，即zval中的is_ref字段为1
		if (variable_ptr!=value) {
			zend_uint refcount = Z_REFCOUNT_P(variable_ptr);

			garbage = *variable_ptr;//旧的zval数据标记后续删除
			*variable_ptr = *value;(value地址对应的zval数据)
			Z_SET_REFCOUNT_P(variable_ptr, refcount);
			Z_SET_ISREF_P(variable_ptr);
			if (!is_tmp_var) {
				zendi_zval_copy_ctor(*variable_ptr);
			}
			zendi_zval_dtor(garbage);
			return variable_ptr;
		}
	} else {
		if (Z_DELREF_P(variable_ptr)==0) {//引用计数减一等于0，即只有一处地方在引用
			if (!is_tmp_var) {
				if (variable_ptr==value) {//指向同一个数据zval结构，引用计数+1
					Z_ADDREF_P(variable_ptr);
				} else if (PZVAL_IS_REF(value)) {//赋值一个引用
					garbage = *variable_ptr;//旧的zval数据标记后续删除
					*variable_ptr = *value;
					INIT_PZVAL(variable_ptr);//初始化zval
					zval_copy_ctor(variable_ptr);
					zendi_zval_dtor(garbage);
					return variable_ptr;
				} else {
					Z_ADDREF_P(value);
					*variable_ptr_ptr = value;
					if (variable_ptr != &EG(uninitialized_zval)) {
						GC_REMOVE_ZVAL_FROM_BUFFER(variable_ptr);
						zval_dtor(variable_ptr);
						efree(variable_ptr);
					}
					return value;
				}
			} else {
				garbage = *variable_ptr;
				*variable_ptr = *value;
				INIT_PZVAL(variable_ptr);
				zendi_zval_dtor(garbage);
				return variable_ptr;
			}
		} else { /* we need to split */
			GC_ZVAL_CHECK_POSSIBLE_ROOT(*variable_ptr_ptr);
			if (!is_tmp_var) {
				if (PZVAL_IS_REF(value) && Z_REFCOUNT_P(value) > 0) {
					ALLOC_ZVAL(variable_ptr);
					*variable_ptr_ptr = variable_ptr;
					*variable_ptr = *value;
					Z_SET_REFCOUNT_P(variable_ptr, 1);
					zval_copy_ctor(variable_ptr);
				} else {
					*variable_ptr_ptr = value;
					Z_ADDREF_P(value);
				}
			} else {
				ALLOC_ZVAL(*variable_ptr_ptr);
				Z_SET_REFCOUNT_P(value, 1);
				**variable_ptr_ptr = *value;
			}
		}
		Z_UNSET_ISREF_PP(variable_ptr_ptr);
	}

	return *variable_ptr_ptr;
}
```