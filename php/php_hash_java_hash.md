#### HashTable
---
bucket我们经常称作桶，HashTable可以看做数组对象，bucket即为数组中的一个元素，当然HashTable在变量管理，资源管理中也被广泛使用。



```C
typedef struct bucket {
	ulong h;			/* Used for numeric indexing */ after time33() hashcode
	uint nKeyLength;    /*key length*/
	void *pData;         // 指向value，一般是用户数据的副本，如果是指针数据，则指向pDataPtr
	void *pDataPtr;	    //如果是指针数据，此值会指向真正的value，同时上面pData会指向此值
	struct bucket *pListNext; // 整个hash表的下一元素
	struct bucket *pListLast; // 整个hash表该元素的上一个元素
	struct bucket *pNext; // 存放在同一个hash Bucket内的下一个元素
	struct bucket *pLast; // 同一个哈希bucket的上一个元素
	char arKey[1]; // 保存当前值所对于的key字符串，这个字段只能定义在最后，实现变长结构体
} Bucket;

typedef struct _hashtable {
	uint nTableSize;  //容量
	uint nTableMask;  //nTableSize - 1
	uint nNumOfElements;   //元素个数
	ulong nNextFreeElement;  // 下一个数字索引的位置
	Bucket *pInternalPointer;	/* Used for element traversal */// 当前遍历的指针
	Bucket *pListHead;// 存储数组头元素指针
	Bucket *pListTail;// 存储数组尾元素指针
	Bucket **arBuckets; // 存储hash数组
	dtor_func_t pDestructor; // 在删除元素时执行的回调函数，用于资源的释放
	zend_bool persistent; //永久分配内存
	unsigned char nApplyCount;// 标记当前hash Bucket被递归访问的次数（防止多次递归）
	zend_bool bApplyProtection;// 标记当前hash桶允许不允许多次访问，不允许时，最多只能递归3次
#if ZEND_DEBUG
	int inconsistent;
#endif
} HashTable;
```

### 基本操作
---
对于HashTable

**key的hash算法**
**常用的操作类型有 query, insert, update, remove**

* 初始化 zend/zend_hash.c
```C
ZEND_API int _zend_hash_init(HashTable *ht, uint nSize, hash_func_t pHashFunction, dtor_func_t pDestructor, zend_bool persistent ZEND_FILE_LINE_DC)
{
	uint i = 3;
	Bucket **tmp;

	SET_INCONSISTENT(HT_OK);

	if (nSize >= 0x80000000) {
		/* prevent overflow */
		ht->nTableSize = 0x80000000;
	} else {
            while ((1U << i) < nSize) {
			i++;
		}
		ht->nTableSize = 1 << i;(Hash表大小始终是2的n次方)
	}

	ht->nTableMask = ht->nTableSize - 1;
	ht->pDestructor = pDestructor;
	ht->arBuckets = NULL;
	ht->pListHead = NULL;
	ht->pListTail = NULL;
	ht->nNumOfElements = 0;
	ht->nNextFreeElement = 0;
	ht->pInternalPointer = NULL;
	ht->persistent = persistent;
	ht->nApplyCount = 0;
	ht->bApplyProtection = 1;
	
	/* Uses ecalloc() so that Bucket* == NULL */
	if (persistent) {
		tmp = (Bucket **) calloc(ht->nTableSize, sizeof(Bucket *));
		if (!tmp) {
			return FAILURE;
		}
		ht->arBuckets = tmp;
	} else {
		tmp = (Bucket **) ecalloc_rel(ht->nTableSize, sizeof(Bucket *));
		if (tmp) {
			ht->arBuckets = tmp;
		}
	}
	
	return SUCCESS;
}
```
Hash表的key计算方式
```C
static inline ulong zend_inline_hash_func(const char *arKey, uint nKeyLength)
{
	register ulong hash = 5381;//register 告诉编译器此变量会被多次使用，建议放在寄存器中

	/* variant with the hash unrolled eight times */
	for (; nKeyLength >= 8; nKeyLength -= 8) {
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
		hash = ((hash << 5) + hash) + *arKey++;
	}
	switch (nKeyLength) {
		case 7: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 6: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 5: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 4: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 3: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 2: hash = ((hash << 5) + hash) + *arKey++; /* fallthrough... */
		case 1: hash = ((hash << 5) + hash) + *arKey++; break;
		case 0: break;
EMPTY_SWITCH_DEFAULT_CASE()
	}
	return hash;
}
```
核心思路 `hash(i) = hash(i-1) * 33 + str[i]`

链表添加数据或更新操作
```C
ZEND_API int _zend_hash_add_or_update(HashTable *ht, const char *arKey, uint nKeyLength, void *pData, uint nDataSize, void **pDest, int flag ZEND_FILE_LINE_DC)
{
	ulong h;
	uint nIndex;
	Bucket *p;

	IS_CONSISTENT(ht);

	if (nKeyLength <= 0) {
#if ZEND_DEBUG
		ZEND_PUTS("zend_hash_update: Can't put in empty key\n");
#endif
		return FAILURE;
	}

	h = zend_inline_hash_func(arKey, nKeyLength);
	nIndex = h & ht->nTableMask;//index计算方式同Java HashMap结构

	p = ht->arBuckets[nIndex];
	while (p != NULL) {
		if ((p->h == h) && (p->nKeyLength == nKeyLength)) {
			if (!memcmp(p->arKey, arKey, nKeyLength)) {//已存在同一个key，进行数据更新
				if (flag & HASH_ADD) {//如果不是更新操作，则退出
					return FAILURE;
				}
				HANDLE_BLOCK_INTERRUPTIONS();
#if ZEND_DEBUG
				if (p->pData == pData) {
					ZEND_PUTS("Fatal error in zend_hash_update: p->pData == pData\n");
					HANDLE_UNBLOCK_INTERRUPTIONS();
					return FAILURE;
				}
#endif
				if (ht->pDestructor) {//销毁旧的数据
					ht->pDestructor(p->pData);
				}
				UPDATE_DATA(ht, p, pData, nDataSize);//执行更新
				if (pDest) {
					*pDest = p->pData;
				}
				HANDLE_UNBLOCK_INTERRUPTIONS();
				return SUCCESS;
			}
		}
		p = p->pNext;
	}
	
	p = (Bucket *) pemalloc(sizeof(Bucket) - 1 + nKeyLength, ht->persistent);//根据是否为永久存储，使用pe方式，动态决断。
	if (!p) {
		return FAILURE;
	}
	memcpy(p->arKey, arKey, nKeyLength);
	p->nKeyLength = nKeyLength;
	INIT_DATA(ht, p, pData, nDataSize);//初始化
	p->h = h;
	CONNECT_TO_BUCKET_DLLIST(p, ht->arBuckets[nIndex]);//将新节点加入HashTable的数组中
	if (pDest) {
		*pDest = p->pData;
	}

	HANDLE_BLOCK_INTERRUPTIONS();
	CONNECT_TO_GLOBAL_DLLIST(p, ht);连接至此Index下最后一个Bucket的下一个
	ht->arBuckets[nIndex] = p;
	HANDLE_UNBLOCK_INTERRUPTIONS();

	ht->nNumOfElements++;
	ZEND_HASH_IF_FULL_DO_RESIZE(ht);		/* If the Hash table is full, resize it */，扩容规则
	return SUCCESS;
}

#define ZEND_HASH_IF_FULL_DO_RESIZE(ht)				\
	if ((ht)->nNumOfElements > (ht)->nTableSize) {	\ /*与Java不同，Java有装载因子，默认0.75*/
		zend_hash_do_resize(ht);					\
	}

static int zend_hash_do_resize(HashTable *ht)
{
	Bucket **t;

	IS_CONSISTENT(ht);

	if ((ht->nTableSize << 1) > 0) {	/* Let's double the table size */
		t = (Bucket **) perealloc_recoverable(ht->arBuckets, (ht->nTableSize << 1) * sizeof(Bucket *), ht->persistent);
		if (t) {
			HANDLE_BLOCK_INTERRUPTIONS();
			ht->arBuckets = t;
			ht->nTableSize = (ht->nTableSize << 1);
			ht->nTableMask = ht->nTableSize - 1;
			zend_hash_rehash(ht);
			HANDLE_UNBLOCK_INTERRUPTIONS();
			return SUCCESS;
		}
		return FAILURE;
	}
	return SUCCESS;
}


ZEND_API int zend_hash_rehash(HashTable *ht)
{
	Bucket *p;
	uint nIndex;

	IS_CONSISTENT(ht);

	memset(ht->arBuckets, 0, ht->nTableSize * sizeof(Bucket *));
	p = ht->pListHead;
	while (p != NULL) {
		nIndex = p->h & ht->nTableMask;
		CONNECT_TO_BUCKET_DLLIST(p, ht->arBuckets[nIndex]);
		ht->arBuckets[nIndex] = p;
		p = p->pListNext;
	}
	return SUCCESS;
}
```
### 相关简单链表操作
```C
#define CONNECT_TO_BUCKET_DLLIST(element, list_head)		\
	(element)->pNext = (list_head);							\
	(element)->pLast = NULL;								\
	if ((element)->pNext) {									\
		(element)->pNext->pLast = (element);				\
	}

#define CONNECT_TO_GLOBAL_DLLIST(element, ht)				\
	(element)->pListLast = (ht)->pListTail;					\
	(ht)->pListTail = (element);							\
	(element)->pListNext = NULL;							\
	if ((element)->pListLast != NULL) {						\
		(element)->pListLast->pListNext = (element);		\
	}														\
	if (!(ht)->pListHead) {									\
		(ht)->pListHead = (element);						\
	}														\
	if ((ht)->pInternalPointer == NULL) {					\
		(ht)->pInternalPointer = (element);					\
	}

#define UPDATE_DATA(ht, p, pData, nDataSize)											\
	if (nDataSize == sizeof(void*)) {													\
		if ((p)->pData != &(p)->pDataPtr) {												\
			pefree_rel((p)->pData, (ht)->persistent);									\
		}																				\
		memcpy(&(p)->pDataPtr, pData, sizeof(void *));									\
		(p)->pData = &(p)->pDataPtr;													\
	} else {																			\
		if ((p)->pData == &(p)->pDataPtr) {												\
			(p)->pData = (void *) pemalloc_rel(nDataSize, (ht)->persistent);			\
			(p)->pDataPtr=NULL;															\
		} else {																		\
			(p)->pData = (void *) perealloc_rel((p)->pData, nDataSize, (ht)->persistent);	\
			/* (p)->pDataPtr is already NULL so no need to initialize it */				\
		}																				\
		memcpy((p)->pData, pData, nDataSize);											\
	}

#define INIT_DATA(ht, p, pData, nDataSize);								\
	if (nDataSize == sizeof(void*)) {									\
		memcpy(&(p)->pDataPtr, pData, sizeof(void *));					\
		(p)->pData = &(p)->pDataPtr;									\
	} else {															\
		(p)->pData = (void *) pemalloc_rel(nDataSize, (ht)->persistent);\
		if (!(p)->pData) {												\
			pefree_rel(p, (ht)->persistent);							\
			return FAILURE;												\
		}																\
		memcpy((p)->pData, pData, nDataSize);							\
		(p)->pDataPtr=NULL;												\
	}
```

#### 针对hash攻击的情形以及相关的攻防策略
---
针对Hash算法存在的碰撞情形进行攻击，消耗cpu计算资源，(使HashTable进行resize && rehash)，并且让底层数组退化为链表。
php5.x解决方案治标不治本, 采用限制POST的变量数，默认为1000个。

```
构造攻击数据后，在PHP54 PHP52以及PHP7下的表现也不同
双核开发机
PHP7 8s+
php54 php52 22s+
```

通过传递json数据，也可以达到同样结果，在json_decode()的时候，将数据转为array，依然会有风险。
