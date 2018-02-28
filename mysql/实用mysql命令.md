## 实用mysql命令

### mysqladmin

执行管理员操作的客户端，支持诸如删除创建数据库，查看配置变量值等

`mysqladmin variables`

### mysqldumpslow

查看慢sql文件

### 客户端 命令

1.  `show variables`查看mysql配置变量
2.  `show global status`查看全局变量配置
3.  `show session status`查看当前会话配置
4.  `show engine innodb status`查看当前数据库 innodb 引擎配置

### 获取DB中所有的表的信息

```sql
SELECT * FROM INFORMATION_SCHEMA.TABLES
```

### 获取所有表的字段信息

```sql
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
```