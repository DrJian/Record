[TOC]

# InnoDB Locking

## 共享锁(S Lock)和排它锁(X Lock)(Shared and Exclusive Locks)

- 拥有S锁的事务可以读取一条行记录
- 拥有X锁的事务可以更新和删除记录

S锁可以同时持有，X锁与S锁互斥，有S锁的时候，在S锁释放前，无法将记录的X锁授予某个事务，反之，记录的X锁授予某个事务后，在X锁释放前，无法授予S锁。

## 意向锁(Intention Lock)

InnoDB支持多种粒度的锁，允许行锁和表锁的并存。例如，语法`LOCK TABLES ... WRITE`会给整张表加一个X锁。为了实现多种粒度-级别(表，行)的锁，InnoDB使用了意向锁。意向锁是表级别的锁，表明事务需要给表中某一行记录加上何种类型的锁(S or X)。

- IS 共享意向锁表明事务想给表的某一行加一个S锁。
- IX 排他意向锁表名事务想给表的某一行加一个X锁。

比如，`SELECT ... FOR SHARE`会设定一个IS Lock，`SELECT ... FOR UPDATE`会设定一个IX Lock。

意向锁的协议如下：

- 事务在获得表的一行记录的S锁之前，必须获得IS Lock或者重量级更高的锁。
- 事务在获得表的一行记录的X锁之前，必须获得表的IX锁。

表级别所得兼容性如下：


|      | X | IX | S  | IS  |
| :----: |:----: | :----: | :----: | :----: |
| X | Conflict | Conflict | Conflict | Conflict |
| IX | Conflict | Compatible | Conflict | Compatible |
| S | Conflict | Conflict | Compatible | Compatible |
| IS | Conflict | Compatible | Compatible | Compatible |

在兼容情况下，锁会被授予事务，如果出现冲突，则无法获取锁。事务会一直等待，知道冲突的锁被释放。如果是由于死锁无法获得锁，则事务会进行回滚。

除了锁表以外的DML语句，意向锁不会阻塞任何其他语句，意向锁的主要目的是表明某个事务已锁定某行记录或将要锁定表里的一行。

意向锁的事务数据，出现在`SHOW ENGINE INNODB STATUS`中

```shell
TABLE LOCK table `test`.`t` trx id 10080 lock mode IX
```

## 行锁(Record Lock)

行锁是锁在索引记录上的一种锁类型，注意这里指的是锁定索引。

## 间隙锁(Gap Lock)

间隙锁锁定索引记录之间的数据，或者第一条记录之前，最后一条记录之后的数据。

间隙锁是性能和并发的部分折衷，用在某些事务隔离级别。

间隙锁在使用唯一索引去寻找一条唯一的记录时，并不适用，会转化为行锁。对于多个列的唯一索引，近使用部分列的情况下，间隙锁依然会发生作用。

未使用索引以及使用非唯一索引的case下，间隙锁会发挥作用。

InnoDB的间隙锁是非常单纯的**阻止插入**，因为它仅阻止其他的事务向间隙中**插入数据**，不会阻止其他事务在相同的间隙上获取间隙锁，所以Gap-X锁和Gap-S锁的作用是一样的。

间隙锁可以被关闭，当我们把数据库隔离级别调至提交读，同时事务会读到快照数据的最新版本。

## Next-Key Lock

同时锁住行记录与间隙。

行锁是InnoDB在扫描表的索引时，将遇到的匹配的行记录加上S锁或X锁。所以行锁其实是索引记录的锁。针对PR级别的锁，使用Record Lock+Gap Lock。但如果使用唯一或者主键索引，锁细化为行锁。InnoDB借助Next-Key Lock避免幻读的产生。

### 关于幻读

幻读指的是在同一个事务中，两次select返回的结果不同，比如第一次select，仅有id为1的记录，第二次select多出来一行id为2的记录，这便是幻读。针对这个问题，可以通过获取间隙锁，来避开自己间隙中的插入动作。

如果在不同的间隙，除非获取对应间隙锁，否则是无效的。

# 关于间隙锁的实验结论

## 表结构组成

- 主键 `id`
- 普通索引`idx_val`

```mysql
mysql> show create table test\G
*************************** 1. row ***************************
       Table: test
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL,
  `val` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_val` (`val`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin
```

## 表的初始数据

```mysql
mysql> select * from test;
+----+------+
| id | val  |
+----+------+
|  0 |    0 |
|  1 |    1 |
|  2 |    2 |
|  5 |    5 |
|  6 |    6 |
|  7 |    7 |
|  8 |    8 |
+----+------+
7 rows in set (0.00 sec)
```

## 间隙锁仅防止插入，针对主键(唯一键)加锁

**注意对于多列的唯一索引，必须使用到所有列才会降级行锁，否则也会Next-Key Lock**

### 对不存在的记录加锁

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from test where id = 4 for update;
Empty set (0.00 sec)
```

`Session B`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into test set id = 4,val = 4;
Blocking....(后来手动kill)
mysql> insert into test set id = 3,val = 3;
Blocking....(后来手动kill)

mysql> update test set val = 22 where id = 2;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> update test set val = 55 where id = 5;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

Session A拥有Gap Lock，Session B无法插入间隙内数据，但可以执行更新。

### 对存在的记录加锁

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from test where id = 5 for update;
+----+------+
| id | val  |
+----+------+
|  5 |    5 |
+----+------+
```

`Session B`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> update test set val=66 where id = 6;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> update test set val=55 where id = 5;
Blocking...

mysql> insert into test set id = 4,val=4;
Query OK, 1 row affected (0.00 sec)
```

Session A使用唯一键，获取到存在记录的Record Lock，所以Session B可以对Record Lock记录以外的记录进行insert update

## 间隙锁仅防止插入，针对二级索引加锁

### 对不存在记录加锁

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from test where val = 4 for update;
Empty set (0.01 sec)
```

`Session B`

```mysql
mysql> insert into test set id = 3, val = 3;
Blocking...
mysql> insert into test set id = 4, val = 4;
Blocking...

mysql> update test set val = 55 where id = 5\G
Query OK, 1 row affected (0.00 sec)
```

Session A 获取Gap Lock，Session B无法insert，但可以对其他记录update

### 对存在记录加锁

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from test where val = 5 for update;
+----+------+
| id | val  |
+----+------+
|  5 |    5 |
+----+------+
1 row in set (0.00 sec)
```

`Session B`

```mysql
mysql> begin;

mysql> insert into test set id = 3, val = 3;
Blocking...

mysql> insert into test set id = 4, val = 4;
Blocking...

mysql> update test set val = 55 where id = 5;
Blocking...

mysql> update test set val = 66 where id = 6;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

Session A获取到了Next-Key Lock，Session B无法在间隙进行insert，无法修改有Record  Lock的id为5的记录，但可以对id5以外的间隙内其他记录进行update。