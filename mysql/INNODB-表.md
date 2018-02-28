[TOC]

## 关于主键的选择

在没有显示定义主键的情况下，按照以下两种条件进行选择：

1.  如果有非空的唯一键（UNIQUE NOT NULL），该列即为主键
2.  不满足上述，创建一个6字节大小的指针

## InnoDB存储的逻辑结构

一个数据库表的空间逻辑排列由上到下为 表(Table)->段(Segment)->区(Extent)->Block(块)/Page(页)  在Oracle最下面一层的逻辑结构为Block(块)，在InnoDB中叫作页(Page)

### InnoDB表空间文件

存放数据表的实际数据的文件，后缀为.ibd，`show variables like '%innodb_file_per_table%';`这个变量开启，我们会为每个db的table存储一个文件，路径参考`show variables like '%datadir%;`在同目录下还会有表结构的定义文件，后缀.frm

###关于size限制

#### varchar

关于varchar(N)类型的字段，长度限制N指的是字符数，对于ascii编码，和字节数是相等的，但是对于GBK,UTF8则分别对应2N,3N字节数，varchar的最大长度为65535个字节，这取决于此InnoDB标的行存储格式，在5.1流行的Compact行存储中，针对变长列的长度记录规则如下：

>   长度小于255使用一个字节，长度大于255使用两个字节，所以两个字节的最大长度记录为2^16-1=65535

#### InnoDB表限制

-   InnoDB数据表最多仅能拥有1017个column
-   每一行的所有字段共享行最大size值，如下建表语句会直接报错，由于长度超过最大值create table test(a varchar(60000), b varchar(5536)) engine=innodb charset=latin1;`

#### InnoDB行限制

尽管不同数据库引擎实际存储数据的方式不同，引擎之间对于行数据的支持不尽相同，但是mysql内部对于行的大小限制为65535字节。比如InnoDB引擎的行限制为page(页)大小的一半略小，16KB的页大小允许Row size达到8000+bytes，但是由于mysql本身的限制，不能超过65535bytes，所以这里就只能是65535字节，当然也会受到物理Row的存储格式影响。

不同的`row_format`也会影响表行的存储，因为不同的模式物理文件每行的记录方式有差异，可查看`innodb_default_row_format`变量查看默认值，针对特定表，执行`show table status`。

#### InnoDB页大小限制

查看`innodb_page_size`变量的设定，一般默认为16KB。

### InnoDB行模式

#### 通用概念

-   Clustered Indexs(聚簇索引)，通常为主键，在没有主键的情况下，生成6字节的RowId作为索引key，最大的特点是顺序性，聚簇索引记录的逻辑顺序与物理存储顺序一致，小->大
-   Secondary Indexs(非聚簇索引)，逻辑顺序与物理顺序无关系，比如非主键column N，N的大小与实际存储位置的先后无关联。

上述两种索引的区别：叶节点存放的是否是一整行数据，聚簇索引存放的是一整行数据(存放于数据页中)，非聚簇索引存放的是主键id。

#### Redundant Row Format Characteristics

-   可以兼容旧版本(<5.0)mysql InnoDB的格式
-   每一行都包含一个6字节的头，用来链接连续的记录(类似链表的概念，包括下一行记录开始位置相对于本行开始位置的偏移量)以及行锁定。
-   6字节事务id，7字节回滚指针
-   无主键情况下，包含一个6字节RowId
-   非聚簇索引中如果不包括相关聚簇索引的主键，则将主键值同时记录在非聚簇索引中。
-   记录字典？每个记录都包含一个指向所有字段的二阶指针，**待确认**。
-   变长类型不补全值，根据实际长度存储。
-   对于长度超过768byte的定长字段，会被当做变长类型对待。
-   NULL值会花费1或2字节存储，如果是变长字段，不消耗额外空间，在头信息中即可解决。

#### COMPACT Row Format Characteristics

>与Redundant相比，节省了文件空间，但是增加了CPU负担，如果是缓存命中或磁盘IO能力短板的系统，使用这个格式，可以获得更多的收益。但是如果是CPU计算能力短板类型的系统，使用此格式反而会降低性能。

-   每一行包含一个5字节的记录头，版本不同，可能位于变长字段列表前面，用于关联行记录以及行锁定。
-   变量长度信息部分，对NULL的判断，如果有N个字段可能为NULL，则此部分长度为((N+7)/8)byte，为NULL的字段除了在NULL part占据一个bit外，不占据其他空间。变量长度信息包括变长字段长度信息的记录，固定长度的字段无此信息，如果表无变长列且都为定长类型，则记录头无此部分。
-   记录头内容后面紧跟的就是非NULL的字段值。
-   聚簇索引包含了所有的用户定义列，除此以外，还有6字节的事务id以及7字节的回滚指针值。
-   如果表无主键，则使用6字节的RowId
-   每一个二级索引都包含了主键，如果主键是变长的，行记录会有一个变长信息部分来记录，无论二级索引定义在定长字段与否。
-   针对非变长字符，按照定长格式存储，不清除varchar后append的空格
-   对于长度超过768byte的定长字段，会被当做变长类型对待。
-   BLOB格式只存储768字节前缀，其余内容放在溢出页中。

#### DYNAMIC and COMPRESSED Row Formats

-   这两种格式都是COMPACT格式的变种，使用这两种格式，可以以(off-page)溢出页的形式存储长字段的变量类型(比如varchar,varbinary,blob,text)，聚簇索引记录仅包含一个20字节的指针，指向溢出页。对于长度超过768byte的定长字段，会被当做变长类型对待。
-   针对多字节编码情况下的字符类型，比如char,实际上内部也会使用变长类型进行存储。
-   如若行记录过长，innodb会循环选择将最长的字段进行溢出页存储，直到聚簇索引满足B-tree页的要求。text和blob类列，如果长度小于40字节，则采用行内存储的方式，而不使用溢出页的方
-   DYNAMIC会在合适的情况下降行数据都存在索引节点内，但是避免了一个B-tree节点存储过长字段的大数据，DYNAMIC的理论基础是，如果一个长数据的一部分存储在溢出页中，将所有数据都存储在溢出页中是一个最高效的做法，DYNAMIC格式下，短一些的列更有可能保留在B-tree节点内，将每行记录的溢出页最小化。
-   COMPRESSED在溢出页的使用上和DYNAMIC使用相似的处理，更多去考虑索引数据的压缩和页体积的最小化。`KEY_BLOCK_SIZE`会决定局促索引存储多少数据以及溢出页的数据存储量。
-   这两种格式都支持索引前缀长度3072字节。(???待确认)

### InnoDB数据页结构

页是InnoDB引擎管理数据库的最小磁盘单位，页类型为B-tree node类型，存放的是表中的实际数据。自上而下由FileHeader,PageHeader,Infimun+supremum records，UserRecords，FreeSpace，PageDirectory，FileTrailer。

#### FileHeader(文件头)

固定为38字节

-   checksum值
-   表空间中页的偏移量
-   当前页的上一页以及下一页，以此保证B+树的性质
-   该页最后被修改的日志序列位置LSN(Log Sequence Number)
-   页的类型
-   该页所属表空间的id

####PageHeader(页头)

56字节

-   页目录(PageDirectory)的槽数
-   堆中第一个记录的指针
-   堆中的记录数
-   指向空闲列表首的指针
-   已删除记录的字节数，即行记录中delete_flag为1的记录
-   最后插入记录的位置
-   该页的记录数
-   当前树在索引树中的位置，0x00代表页节点
-   当前页属于哪个索引
-   B+树叶节点中，文件段的首指针位置
-   B+树叶f非节点中，文件段的首指针位置

#### Infimun+supremum records(上下确界记录)

分别比该页中任意记录主键都小和都大的记录

#### UserRecords(用户记录，即行记录) FreeSpace(空闲空间)

用户记录即为实际的物理行结构，记录被删除后，空间会加入空闲空间，是个链表。

#### PageDirectory(页目录)

待续。

#### FileTrailer(文件尾)

保证页完全写入磁盘，由8个字节组成，前四个字节为FileHeader中的checksum值，当然需要调用InnoDB的checksum函数比较，后四个字节为FileHeader中的LSN值。

### InnoDb File Format

InnoDB Plugin前的file format定义为Antelope，新的文件格式定义为Barracuda，新的格式都会兼容之前的旧的格式，包含旧格式的row format，并新增了DYNAMIC,COMPRESSED格式。

