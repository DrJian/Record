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

## 行锁LOCK_REC_NOT_GAP)

行锁是锁在索引记录上的一种锁类型，注意这里指的是锁定索引。

## 间隙锁(LOCK_GAP)

间隙锁锁定索引记录之间的数据，或者第一条记录之前，最后一条记录之后的数据。

间隙锁是性能和并发的部分折衷，用在某些事务隔离级别。

间隙锁在使用唯一索引去寻找一条唯一的记录时，并不适用，会转化为行锁。对于多个列的唯一索引，近使用部分列的情况下，间隙锁依然会发生作用。

未使用索引以及使用非唯一索引的case下，间隙锁会发挥作用。

InnoDB的间隙锁是非常单纯的**阻止插入**，因为它仅阻止其他的事务向间隙中**插入数据**，不会阻止其他事务在相同的间隙上获取间隙锁，所以Gap-X锁和Gap-S锁的作用是一样的。

间隙锁可以被关闭，当我们把数据库隔离级别调至提交读，同时事务会读到快照数据的最新版本。

## Next-Key Lock(LOCK_ORDINARY)

同时锁住行记录与间隙，即Record Lock 与 Gap Lock的结合。

行锁是InnoDB在扫描表的索引时，将遇到的匹配的行记录加上S锁或X锁。所以行锁其实是索引记录的锁。针对PR的隔离级别，使用Record Lock+Gap Lock。但如果使用唯一或者主键索引，锁细化为行锁。InnoDB借助Next-Key Lock避免幻读的产生。

### 关于幻读

幻读指的是在同一个事务中，两次select返回的结果不同，比如第一次select，仅有id为1的记录，第二次select多出来一行id为2的记录，这便是幻读。针对这个问题，可以通过获取间隙锁，来避开自己间隙中的插入动作。

如果在不同的间隙，除非获取对应间隙锁，否则是无效的。

## 插入意向锁(Insert Intention Lock)

插入意向锁是在插入行记录之前由插入操作触发的一种**间隙锁**。这表明了插入的意愿，在多个事务都在同一间隙的不同位置执行插入操作时不用等待。

> 假定现在有4和7的两条索引记录，两个不同的事务去插入5和6的索引记录，在获取插入记录的互斥锁(X Lock)之前，分别在同一间隙设置了插入意向锁，当然前提是插入不同的两条记录，如果两个事务插入相同的记录，有一个无法获取插入意向锁。

### 实验一

初始数据

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

CREATE TABLE `test` (
  `id` int(11) NOT NULL,
  `val` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_val` (`val`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin
```

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.01 sec)

mysql> select * from test where id > 2 for update;
+----+------+
| id | val  |
+----+------+
|  5 |    5 |
|  6 |    6 |
|  7 |    7 |
|  8 |    8 |
+----+------+
4 rows in set (0.00 sec)
```

`Session B`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into test set id = 3, val = 3;
Blocking
```

查看innodb引擎目前的执行状况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16172:54:3:7
lock_trx_id: 16172
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
*************************** 2. row ***************************
    lock_id: 16171:54:3:7
lock_trx_id: 16171
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
2 rows in set, 1 warning (0.01 sec)

mysql>show engine innodb status;

---TRANSACTION 16172, ACTIVE 2 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 4, OS thread handle 123145403211776, query id 164 localhost root update
insert into test set id = 3, val = 3
------- TRX HAS BEEN WAITING 2 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 3 n bits 80 index PRIMARY of table `hongjian`.`test` trx id 16172 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 4; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 6; hex 000000003d3f; asc     =?;;
 2: len 7; hex ac00000120011c; asc        ;;
 3: len 4; hex 80000005; asc     ;;
```

**结论**

Session A获取Gap Lock+id > 2记录(5,6)的X锁，观察日志，Session B等待id 3记录的插入意向锁。

### 实验二

初始数据

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

CREATE TABLE `test` (
  `id` int(11) NOT NULL,
  `val` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_val` (`val`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin
```

`Session A`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from test where id = 3 for update;
Empty set (0.00 sec)
```

`Session B`

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into test set id = 3, val = 3;
Blocking
```

查看innodb引擎目前的执行状况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16174:54:3:7
lock_trx_id: 16174
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
*************************** 2. row ***************************
    lock_id: 16173:54:3:7
lock_trx_id: 16173
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
2 rows in set, 1 warning (0.00 sec)

mysql> show engine innodb status\G

---TRANSACTION 16174, ACTIVE 2 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 4, OS thread handle 123145403211776, query id 172 localhost root update
insert into test set id = 3, val = 3
------- TRX HAS BEEN WAITING 2 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 3 n bits 80 index PRIMARY of table `hongjian`.`test` trx id 16174 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 4; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 6; hex 000000003d3f; asc     =?;;
 2: len 7; hex ac00000120011c; asc        ;;
 3: len 4; hex 80000005; asc     ;;
```

**结论**

Session A获取到了id 3 记录的Record Lock + Gap Lock，观察日志，Session B等待id 3记录的插入意向锁。

### 实验三

初始数据

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

CREATE TABLE `test` (
  `id` int(11) NOT NULL,
  `val` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_val` (`val`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin
```

`Session A`

```mysql
begin;

mysql> select * from test where id > 2 for update;
```

`Session B`

```mysql
begin;

mysql> update test set val = 55 where id = 5;
Blocking
```

查看innodb引擎目前的执行状况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16176:54:3:7
lock_trx_id: 16176
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
*************************** 2. row ***************************
    lock_id: 16175:54:3:7
lock_trx_id: 16175
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
2 rows in set, 1 warning (0.01 sec)

mysql> show engine innodb status\G

---TRANSACTION 16176, ACTIVE 1 sec starting index read
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 4, OS thread handle 123145403211776, query id 181 localhost root updating
update test set val = 55 where id = 5
------- TRX HAS BEEN WAITING 1 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 3 n bits 80 index PRIMARY of table `hongjian`.`test` trx id 16176 lock_mode X locks rec but not gap waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 4; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 6; hex 000000003d3f; asc     =?;;
 2: len 7; hex ac00000120011c; asc        ;;
 3: len 4; hex 80000005; asc     ;;
```

**结论**

Session A获取到了多行(5,6)X Lock + Gap Lock，观察日志，Session B等待id 3记录的Record Lock。

## 自增锁

在执行插入时，针对自增的列会用到，如果一个事务对表A进行插入，其他对表A进行插入的事务必须等待，因此在合并插入的时候，可以保证列数值的连续性。

# 锁的兼容性图谱

| 第一行为已持有的锁，第一列为正在请求的锁 |    Gap     | Insert Intention |   Record   |  Next-Key  |
| :--------------------------------------: | :--------: | :--------------: | :--------: | :--------: |
|                   Gap                    | Compatible |    Compatible    | Compatible | Compatible |
|             Insert Intention             |  Conflict  |    Compatible    | Compatible |  Conflict  |
|                  Record                  | Compatible |    Compatible    |  Conflict  |  Conflict  |
|                 Next-Key                 | Compatible |    Compatible    |  Conflict  |  Conflict  |



# 关于间隙锁的实验

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

查看innodb引擎执行情况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16170:54:3:7
lock_trx_id: 16170
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
*************************** 2. row ***************************
    lock_id: 16169:54:3:7
lock_trx_id: 16169
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
2 rows in set, 1 warning (0.00 sec)

mysql> show engine innodb status\G

---TRANSACTION 16170, ACTIVE 1 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 4, OS thread handle 123145403211776, query id 156 localhost root update
insert into test set id = 4,val = 4
------- TRX HAS BEEN WAITING 1 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 3 n bits 80 index PRIMARY of table `hongjian`.`test` trx id 16170 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 4; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 6; hex 000000003d3f; asc     =?;;
 2: len 7; hex ac00000120011c; asc        ;;
 3: len 4; hex 80000005; asc     ;;
```

**总结**

Session A拥有Gap Lock + 对应记录的X Lock，Session B无法插入间隙内数据，但可以执行其他记录的更新，Session B在等待获取插入意向锁。

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

查看innodb引擎执行情况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16166:54:3:7
lock_trx_id: 16166
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
*************************** 2. row ***************************
    lock_id: 16165:54:3:7
lock_trx_id: 16165
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: PRIMARY
 lock_space: 54
  lock_page: 3
   lock_rec: 7
  lock_data: 5
2 rows in set, 1 warning (0.00 sec)

mysql> show engine innodb status\G

---TRANSACTION 16166, ACTIVE 2 sec starting index read
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 4, OS thread handle 123145403211776, query id 133 localhost root updating
update test set val=55 where id = 5
------- TRX HAS BEEN WAITING 2 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 3 n bits 80 index PRIMARY of table `hongjian`.`test` trx id 16166 lock_mode X locks rec but not gap waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 4; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 6; hex 000000003d3f; asc     =?;;
 2: len 7; hex ac00000120011c; asc        ;;
 3: len 4; hex 80000005; asc     ;;
```

**结论**

Session A使用唯一键，获取到存在记录的X Lock，所以Session B可以对Record Lock记录以外的记录进行insert update，Session B在等待该记录的X锁。

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
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into test set id = 3, val = 3;
Blocking...
mysql> insert into test set id = 4, val = 4;
Blocking...

mysql> update test set val = 55 where id = 5\G
Query OK, 1 row affected (0.00 sec)
```

查看innodb引擎执行情况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16168:54:4:7
lock_trx_id: 16168
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: idx_val
 lock_space: 54
  lock_page: 4
   lock_rec: 7
  lock_data: 5, 5
*************************** 2. row ***************************
    lock_id: 16167:54:4:7
lock_trx_id: 16167
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: idx_val
 lock_space: 54
  lock_page: 4
   lock_rec: 7
  lock_data: 5, 5
2 rows in set, 1 warning (0.00 sec)

mysql> show engine innodb status\G

---TRANSACTION 281479545839168, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 16168, ACTIVE 1 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s), undo log entries 1
MySQL thread id 4, OS thread handle 123145403211776, query id 141 localhost root update
insert into test set id = 3, val = 3
------- TRX HAS BEEN WAITING 1 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 4 n bits 80 index idx_val of table `hongjian`.`test` trx id 16168 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 2; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 4; hex 80000005; asc     ;;
```

**结论**

Session A 获取Gap Lock+对应记录的X Lock，Session B无法insert，等待插入意向锁，但可以对其他记录update

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

查看innodb引擎执行情况

```mysql
mysql> select * from information_schema.INNODB_LOCKS\G
*************************** 1. row ***************************
    lock_id: 16164:54:4:7
lock_trx_id: 16164
  lock_mode: X,GAP
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: idx_val
 lock_space: 54
  lock_page: 4
   lock_rec: 7
  lock_data: 5, 5
*************************** 2. row ***************************
    lock_id: 16163:54:4:7
lock_trx_id: 16163
  lock_mode: X
  lock_type: RECORD
 lock_table: `hongjian`.`test`
 lock_index: idx_val
 lock_space: 54
  lock_page: 4
   lock_rec: 7
  lock_data: 5, 5
2 rows in set, 1 warning (0.00 sec)

mysql> show engine innodb status\G

---TRANSACTION 16164, ACTIVE 1 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s), undo log entries 1
MySQL thread id 4, OS thread handle 123145403211776, query id 112 localhost root update
insert into test set id = 3, val = 3
------- TRX HAS BEEN WAITING 1 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 54 page no 4 n bits 80 index idx_val of table `hongjian`.`test` trx id 16164 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 7 PHYSICAL RECORD: n_fields 2; compact format; info bits 0
 0: len 4; hex 80000005; asc     ;;
 1: len 4; hex 80000005; asc     ;;
```

**结论**

Session A获取到了Next-Key Lock，Session B无法在间隙进行insert，等待插入意向锁，无法修改Record  Lock的id为5的记录，但可以对id5以外的间隙内其他记录进行update。