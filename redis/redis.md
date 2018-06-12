[TOC]

# Redis Object

Redis使用对象来表示数据库中的键和值，每当我们在redis数据库中创建一个新的键值对时，会通常创建至少两个对象，一个是键对象，一个是值对象。

## 对象类型与编码

对象的编码即为底层选取的数据类型

### 定义

```c
typedef struct redisObject {

    // 类型
    unsigned type:4;

    // 编码
    unsigned encoding:4;

    // 对象最后一次被访问的时间
    unsigned lru:REDIS_LRU_BITS; /* lru time (relative to server.lruclock) */

    // 引用计数
    int refcount;

    // 指向实际值的指针
    void *ptr;

} robj;
```

```c
/* Object types */
// 对象类型
#define REDIS_STRING 0
#define REDIS_LIST 1
#define REDIS_SET 2
#define REDIS_ZSET 3
#define REDIS_HASH 4

/* Objects encoding. Some kind of objects like Strings and Hashes can be
 * internally represented in multiple ways. The 'encoding' field of the object
 * is set to one of this fields for this object. */
// 对象编码
#define REDIS_ENCODING_RAW 0     /* Raw representation */
#define REDIS_ENCODING_INT 1     /* Encoded as integer */
#define REDIS_ENCODING_HT 2      /* Encoded as hash table */
#define REDIS_ENCODING_ZIPMAP 3  /* Encoded as zipmap */
#define REDIS_ENCODING_LINKEDLIST 4 /* Encoded as regular linked list */
#define REDIS_ENCODING_ZIPLIST 5 /* Encoded as ziplist */
#define REDIS_ENCODING_INTSET 6  /* Encoded as intset */
#define REDIS_ENCODING_SKIPLIST 7  /* Encoded as skiplist */
#define REDIS_ENCODING_EMBSTR 8  /* Embedded sds string encoding */
```

### 查看编码类型

```
OBJECT ENCODING  key_name
```

## 字符串对象

### 可用编码类型

- REDIS_ENCODING_RAW
- REDIS_ENCODING_INT
- REDIS_ENCODING_EMBSTR

### 编码类型使用界定

#### REDIS_ENCODING_INT

set时使用的数字在long的大小限定内，则会使用int进行存储，这里注意是有符号的。下面的例子是64位操作系统的结果。

```shell
127.0.0.1:6379> set test 9223372036854775807
OK
127.0.0.1:6379> object encoding test
"int"
127.0.0.1:6379> set test 9223372036854775808
OK
127.0.0.1:6379> object encoding test
"embstr"
127.0.0.1:6379> set test -9223372036854775808
OK
127.0.0.1:6379> object encoding test
"int"
127.0.0.1:6379> set test -9223372036854775809
OK
127.0.0.1:6379> object encoding test
"embstr"
```

### REDIS_ENCODING_RAW

长度大于32字节的value，两次分配内存给redisObject 和 sdshdr对象

### REDIS_ENCODING_EMBSTR

长度小于32自己的value，分配一段连续的内存给redisObject 和 sdshdr对象，减少销毁开销。

### 浮点数

浮点数使用字符串存储，不使用int，对于浮点数加减，会先转为浮点数，计算完成后再用字符串存储。

## 列表对象

```C
robj->ptr->linkedlist_obj
linkedlist->list_node->value->string_obj(sds)
```

### 可用编码类型

- REDIS_ENCODING_LINKEDLIST
- REDIS_ENCODING_ZIPLIST

### REDIS_ENCODING_ZIPLIST

### REDIS_ENCODING_LINKEDLIST

### 编码界定

列表保存的所有元素长度都小于64字节且元素数量小于512个(可以通过配置修改)，使用`REDIS_ENCODING_ZIPLIST`编码，否则使用`REDIS_ENCODING_LINKEDLIST`

## Hash对象

### 可用编码类型

- REDIS_ENCODING_HT
- REDIS_ENCODING_ZIPLIST

### 编码界定

Hash保存的所有元素长度都小于64字节且元素数量小于512个(可以通过配置修改)，使3用`REDIS_ENCODING_ZIPLIST`编码，否则使用`REDIS_ENCODING_HASHTABLE`

### REDIS_ENCODING_ZIPLIST

```shell
连续内存存储key-val,ziplist示意图如下
每个新的key-val对会被当做两个新的节点依序加入表尾
|zlbytes|zltail|zllen|key-entry|val-entry|zlend|
```

### REDIS_ENCODING_HT

底层为字典的数据结构

## 集合对象

### 可用编码类型

- REDIS_ENCODING_INTSET
- REDIS_ENCODING_HT(Dict结构)

### REDIS_ENCODING_HT

###REDIS_ENCODING_INTSET 

### 编码界定

集合对象所保存的元素都是整数且集合保存的元素数量不超过512个，使用`REDIS_ENCODING_INTSET`否则使用`REDIS_ENCODING_HT`

## 有序集合对象

对于`zset`结构使用skiplist和dict两个属性，既保证了直接查询的速度，也满足了排序的需求，空间换时间。

### 可用编码类型

- REDIS_ENCODING_ZIPLIST
- REDIS_ENCODING_SKIPLIST

### 编码界定

集合对象所保存的元素长度小于64字节且集合保存的元素数量不超过128个，使用`REDIS_ENCODING_ZIPLIST`否则使用`REDIS_ENCODING_SKIPLIST`

### REDIS_ENCODING_ZIPLIST

```shell
连续内存存储score-member,ziplist示意图如下
|zlbytes|zltail|zllen|member-entry|score-entry|zlend|
```

分数小->大  前->后

### REDIS_ENCODING_SKIPLIST



# Redis Data Struct

## SDS (Simple Dynamic String)

```c
/*
 * 类型别名，用于指向 sdshdr 的 buf 属性
 */
typedef char *sds;

/*
 * 保存字符串对象的结构
 */
struct sdshdr {
    
    // buf 中已占用空间的长度
    int len;

    // buf 中剩余可用空间的长度
    int free;

    // 数据空间
    char buf[];
};
```

##Linked List

```c
/*
 * 双端链表节点
 */
typedef struct listNode {

    // 前置节点
    struct listNode *prev;

    // 后置节点
    struct listNode *next;

    // 节点的值
    void *value;

} listNode;

/*
 * 双端链表迭代器
 */
typedef struct listIter {

    // 当前迭代到的节点
    listNode *next;

    // 迭代的方向
    int direction;

} listIter;

/*
 * 双端链表结构
 */
typedef struct list {

    // 表头节点
    listNode *head;

    // 表尾节点
    listNode *tail;

    // 节点值复制函数
    void *(*dup)(void *ptr);

    // 节点值释放函数
    void (*free)(void *ptr);

    // 节点值对比函数
    int (*match)(void *ptr, void *key);

    // 链表所包含的节点数量
    unsigned long len;

} list;
```

## ZipList

```c
/* Utility macros */
/*
 * ziplist 属性宏
 */
// 定位到 ziplist 的 bytes 属性，该属性记录了整个 ziplist 所占用的内存字节数
// 用于取出 bytes 属性的现有值，或者为 bytes 属性赋予新值
#define ZIPLIST_BYTES(zl)       (*((uint32_t*)(zl)))
// 定位到 ziplist 的 offset 属性，该属性记录了到达表尾节点的偏移量
// 用于取出 offset 属性的现有值，或者为 offset 属性赋予新值
#define ZIPLIST_TAIL_OFFSET(zl) (*((uint32_t*)((zl)+sizeof(uint32_t))))
// 定位到 ziplist 的 length 属性，该属性记录了 ziplist 包含的节点数量
// 用于取出 length 属性的现有值，或者为 length 属性赋予新值
#define ZIPLIST_LENGTH(zl)      (*((uint16_t*)((zl)+sizeof(uint32_t)*2)))
// 返回 ziplist 表头的大小
#define ZIPLIST_HEADER_SIZE     (sizeof(uint32_t)*2+sizeof(uint16_t))
// 返回指向 ziplist 第一个节点（的起始位置）的指针
#define ZIPLIST_ENTRY_HEAD(zl)  ((zl)+ZIPLIST_HEADER_SIZE)
// 返回指向 ziplist 最后一个节点（的起始位置）的指针
#define ZIPLIST_ENTRY_TAIL(zl)  ((zl)+intrev32ifbe(ZIPLIST_TAIL_OFFSET(zl)))
// 返回指向 ziplist 末端 ZIP_END （的起始位置）的指针
#define ZIPLIST_ENTRY_END(zl)   ((zl)+intrev32ifbe(ZIPLIST_BYTES(zl))-1)

/*
 * 保存 ziplist 节点信息的结构
 */
typedef struct zlentry {

    // prevrawlensize ：编码 prevrawlen 所需的字节大小
    // prevrawlen ：前置节点的长度
    unsigned int prevrawlensize, prevrawlen;

    // lensize ：编码 len 所需的字节大小
    // len ：当前节点值的长度
    unsigned int lensize, len;

    // 当前节点 header 的大小
    // 等于 prevrawlensize + lensize
    unsigned int headersize;

    // 当前节点值所使用的编码类型
    unsigned char encoding;

    // 指向当前节点的指针
    unsigned char *p;

} zlentry;
```

## Dict

```c
/* This is our hash table structure. Every dictionary has two of this as we
 * implement incremental rehashing, for the old to the new table. */
/*
 * 哈希表
 *
 * 每个字典都使用两个哈希表，从而实现渐进式 rehash 。
 */
typedef struct dictht {
    
    // 哈希表数组
    dictEntry **table;

    // 哈希表大小
    unsigned long size;
    
    // 哈希表大小掩码，用于计算索引值
    // 总是等于 size - 1
    unsigned long sizemask;

    // 该哈希表已有节点的数量
    unsigned long used;

} dictht;

/*
 * 字典
 */
typedef struct dict {

    // 类型特定函数
    dictType *type;

    // 私有数据
    void *privdata;

    // 哈希表
    dictht ht[2];

    // rehash 索引
    // 当 rehash 不在进行时，值为 -1
    int rehashidx; /* rehashing not in progress if rehashidx == -1 */

    // 目前正在运行的安全迭代器的数量
    int iterators; /* number of iterators currently running */

} dict;

/* If safe is set to 1 this is a safe iterator, that means, you can call
 * dictAdd, dictFind, and other functions against the dictionary even while
 * iterating. Otherwise it is a non safe iterator, and only dictNext()
 * should be called while iterating. */
/*
 * 字典迭代器
 *
 * 如果 safe 属性的值为 1 ，那么在迭代进行的过程中，
 * 程序仍然可以执行 dictAdd 、 dictFind 和其他函数，对字典进行修改。
 *
 * 如果 safe 不为 1 ，那么程序只会调用 dictNext 对字典进行迭代，
 * 而不对字典进行修改。
 */
typedef struct dictIterator {
        
    // 被迭代的字典
    dict *d;

    // table ：正在被迭代的哈希表号码，值可以是 0 或 1 。
    // index ：迭代器当前所指向的哈希表索引位置。
    // safe ：标识这个迭代器是否安全
    int table, index, safe;

    // entry ：当前迭代到的节点的指针
    // nextEntry ：当前迭代节点的下一个节点
    //             因为在安全迭代器运作时， entry 所指向的节点可能会被修改，
    //             所以需要一个额外的指针来保存下一节点的位置，
    //             从而防止指针丢失
    dictEntry *entry, *nextEntry;

    long long fingerprint; /* unsafe iterator fingerprint for misuse detection */
} dictIterator;
/*
 * 哈希表节点
 */
typedef struct dictEntry {
    
    // 键
    void *key;

    // 值
    union {
        void *val;
        uint64_t u64;
        int64_t s64;
    } v;

    // 指向下个哈希表节点，形成链表
    struct dictEntry *next;

} dictEntry;


/*
 * 字典类型特定函数
 */
typedef struct dictType {

    // 计算哈希值的函数
    unsigned int (*hashFunction)(const void *key);

    // 复制键的函数
    void *(*keyDup)(void *privdata, const void *key);

    // 复制值的函数
    void *(*valDup)(void *privdata, const void *obj);

    // 对比键的函数
    int (*keyCompare)(void *privdata, const void *key1, const void *key2);

    // 销毁键的函数
    void (*keyDestructor)(void *privdata, void *key);
    
    // 销毁值的函数
    void (*valDestructor)(void *privdata, void *obj);

} dictType;
```

## IntSet

```c
typedef struct intset {
    
    // 编码方式
    uint32_t encoding;

    // 集合包含的元素数量
    uint32_t length;

    // 保存元素的数组
    int8_t contents[];

} intset;
```

## SkipList

```c
/* ZSETs use a specialized version of Skiplists */
/*
 * 跳跃表节点
 */
typedef struct zskiplistNode {

    // 成员对象
    robj *obj;

    // 分值
    double score;

    // 后退指针
    struct zskiplistNode *backward;

    // 层
    struct zskiplistLevel {

        // 前进指针
        struct zskiplistNode *forward;

        // 跨度
        unsigned int span;

    } level[];

} zskiplistNode;

/*
 * 跳跃表
 */
typedef struct zskiplist {

    // 表头节点和表尾节点
    struct zskiplistNode *header, *tail;

    // 表中节点的数量
    unsigned long length;

    // 表中层数最大的节点的层数
    int level;

} zskiplist;

/*
 * 有序集合
 */
typedef struct zset {

    // 字典，键为成员，值为分值
    // 用于支持 O(1) 复杂度的按成员取分值操作
    dict *dict;

    // 跳跃表，按分值排序成员
    // 用于支持平均复杂度为 O(log N) 的按分值定位成员操作
    // 以及范围操作
    zskiplist *zsl;

} zset;
```

