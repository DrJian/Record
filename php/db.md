## mysql与mysqli
1. mysqli的安全性更强，效率更高，mysqli使用永久连接，多次运行mysqli将使用同一进程，减少服务器开销，同时封装了一些诸如事务的高级操作以及DB操作过程中的很多可用方法。mysql使用非持继连接。
2. 后者使用对象方式，前者使用过程方式。

**前者目前已经被废弃，不建议使用**
##pdo与php_mysqli

First Header  | Second Header
------------- | -------------
Content Cell  | Content Cell
Content Cell  | Content Cell