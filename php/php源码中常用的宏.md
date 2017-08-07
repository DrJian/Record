* CG(function_table) and EG(function_table)—These structures refer to the
function table we’ve talked about up until now. It exists in both the compiler and
executor globals. Iterating through this hashtable gives you every callable function.
* CG(class_table) and EG(class_table)—These structures refer to the hashtable
in which all the classes are stored.
* EG(symbol_table)—This structure refers to a hashtable that is the main (that is,
global) symbol table.This is where all the variables in the global scope are stored.
n EG(active_symbol_table)—This structure refers to a hashtable that contains the
symbol table for the current scope.
* EG(zend_constants)—This structure refers to the constants hashtable, where constants
set with the function define are stored.
* CG(auto_globals)—This structure refers to the hashtable of autoglobals
($_SERVER, $_ENV, $_POST, and so on) that are used in the script.This is a compiler
global so that the autoglobals can be conditionally initialized only if the script
utilizes them.This boosts performance because it avoids the work of initializing
and populating these variables when they are not needed.
* EG(regular_list)—This structure refers to a hashtable that is used to store “regular”
(that is, nonpersistent) resources. Resources here are PHP resource-type variables,
such as streams, file pointers, database connections, and so on.You’ll learn
more about how these are used in Chapter 22.
* EG(persistent_list)—This structure is like EG(regular_list), but
EG(persistent_list) resources are not freed at the end of every request (persistent
database connections, for example).
n EG(user_error_handler)—This structure refers to a pointer to a zval that contains
the name of the current user_error_handler function (as set via the
set_error_handler function). If no error-handler function is set, this structure is
NULL.
* EG(user_error_handlers)—This structure refers to the stack of error-handler
functions.
* EG(user_exception_handler)—This structure refers to a pointer to a zval that
contains the name of the current global exception handler, as set via the function
set_exception_handler. If none has been set, this structure is NULL.
* EG(user_exception_handlers)—This structure refers to the stack of global
exception handlers.
* EG(exception)—This is an important structure.Whenever an exception is
thrown, EG(exception) is set to the actual object handler’s zval that is thrown.
Whenever a function call is returned, EG(exception) is checked. If it is not NULL,
492 Chapter 20 PHP and Zend Engine Internals
execution halts and the script jumps to the op for the appropriate catch block.We
will explore throwing exceptions from within extension code in depth in Chapter
21,“Extending PHP: Part I,” and Chapter 22.
* EG(ini_directives)—This structure refers to a hashtable of the php.ini directives
that is set in this execution context.

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