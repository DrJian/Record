HashMap、TreeMap、HashTable是Map接口下三个重要的集合类，在JDK1.8中又有所更新，本篇文章介绍一下他们三个的特点和对比。
##<font color=green>HashMap</font>
顾名思义，学过计算机的同学应该都知Hash，那么HashMap最显著的特点就是利用了Hash散列算法。
###<font color=bray>初始化容量</font> 
1>>4即，2的4次方，也就是16.
HashMap底层也是一个数组，所以也就是底层数组长度为16。
###<font color=bray>扩容因子</font>
默认0.75，用户可以自定义，所谓扩容因子，也就是控制HashMap何时进行扩容resize()操作，这里使用threshold = 0.75*size 来做，当HashMap中元素数量大于这个的时候，那么对HashMap进行扩容操作，大小变为原来的两倍，同理threshold也变为原来的两倍。

	if (++size > threshold)
            resize();
这是put方法下的部代码，可以看到在这里去调用扩容函数。
###<font color=bray>静态内部类Node</font>
	
	Node(int hash, K key, V value, Node<K,V> next) {
            this.hash = hash;
            this.key = key;
            this.value = value;
            this.next = next;
        }
不同key，拥有相同hash(key)值，会被在同一个key下，用链表存起来，链表子元素就是一个节点Node。
###<font color = red>为什么容量要使用2的n次方？</font>
---
这就牵涉到hash的算法:

首先，我们明确HashMap底层是一个数组，既然是数组，算好了hash(key)之后，就应该将key-value放入hash(key)这个下标下。我们看一眼源码中put->putVal，putVal源码：
	
	final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                   boolean evict) {
	if ((tab = table) == null || (n = tab.length) == 0)
    	n = (tab = resize()).length;
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
	}
1. 第一个if做的事情，就是第一次调用时进行初始化容量。
2. 第二个if中，hash即hash(key)的结果，这里使用一个&(n-1)操作，速度远远胜过使用%n这样的模运算，尤其在数量比较大的时候，所以大家应该可以理解为什么HashMap要使用2的n次方，即提高定位的速度。

###<font color = red>JDK8中的hash方法为什么要右移16位？</font>

	static final int hash(Object key) {
        int h;
        return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    }

这个问题我一开始也不懂，后来找到了非常棒的回答，[连接在这里](http://www.zhihu.com/question/20733617),主要内容是一个扰动函数，在JDK1.8中做了优化，总的而言还是为了降低hashmap的碰撞冲突，提高HashMap性能。

##<font color=green>HashTable</font>
与HashMaph很像，HashTable也是采用Hash来做，但是二者也有区别。
###<font color=bray>默认初始化</font>
默认的初始容量大小是11，扩容因子0.75，当然threshold = count * 0.75，这里的count是HashTable的元素个数。

###<font color=bray>扩容策略</font>

	int newCapacity = (oldCapacity << 1) + 1;	
采用二倍加1的扩容方法。新的threshold还是0.75 * count
###<font color=bray>与HashMap区别</font>
1. 除了扩容以外，在所有的方法里都使用了synchronized来做同步，性能上来将，比较低。
2. HashTable底层也是一个数组，那么就牵扯到如何去计算key的hash了，看一看HashTable的实现方法，你就会明白为什么初始值不是16，像HashMap那样使用2的N次方

`
	hash = key.hashCode();
    index = (hash & 0x7FFFFFFF) % tab.length;
`
这里使用的是取模%运算而不是使用&运算，那么在性能又会比HashMap低
##<font color=green>TreeMap</font>
说到tree，大家应该都会想起数据结构中的tree，树里面又有许多种，搜索树，AVL树，红黑树。红黑树由于其在随机性下展现出的稳定性能优势而广泛使用，大家有兴趣可以去自己查看。

###<font color=bray>底层实现</font>
TreeMap的底层是用二叉树来实现的，并且是一颗红黑树，这个在源码中一眼就可以看出来，EntrySet是树的一个子节点定义，代码如下，

	K key;
    V value;
    Entry<K,V> left;
    Entry<K,V> right;
    Entry<K,V> parent;
    boolean color = BLACK;
看到颜色那个变量，不言而喻，红黑树。
###<font color=bray>Comparator</font>
既然是一颗红黑树，自然要有自己的排序策略，这里就得提到Java比较器的概念，通过定义compartTo这个方法，根据返回值来判断两个数据的大小比较结果，进而决定在树中新元素的存放位置，源代码写的很清晰，可以看一下put这个方法

	public V put(K key, V value) {
        Entry<K,V> t = root;//如果TreeMap为空，则新加入的元素作为数组的根节点，
		//modCount在Java许多集合类中都有，只是记录当前类修改的次数，modify count
        if (t == null) {
            compare(key, key); // type (and possibly null) check

            root = new Entry<>(key, value, null);
            size = 1;
            modCount++;
            return null;
        }
        int cmp;
        Entry<K,V> parent;
        // split comparator and comparable paths
        Comparator<? super K> cpr = comparator;
        if (cpr != null) {//如果不为空使用用户传入的比较器，如果为空，则使用默认的比较器
            do {
                parent = t;//注意是使用key在做比较
                cmp = cpr.compare(key, t.key);
                if (cmp < 0)
                    t = t.left;
                else if (cmp > 0)
                    t = t.right;
                else
                    return t.setValue(value);
            } while (t != null);
        }
        else {
            if (key == null)
                throw new NullPointerException();
            @SuppressWarnings("unchecked")
                Comparable<? super K> k = (Comparable<? super K>) key;
            do {
                parent = t;
                cmp = k.compareTo(t.key);
                if (cmp < 0)
                    t = t.left;
                else if (cmp > 0)
                    t = t.right;
                else
                    return t.setValue(value);
            } while (t != null);
        }
        Entry<K,V> e = new Entry<>(key, value, parent);
        if (cmp < 0)
            parent.left = e;
        else
            parent.right = e;
        fixAfterInsertion(e);//插入新节点后，对树采用红黑树平衡策略，这个函数里面就是红黑树的平衡代码，大家可以自己去看。
        size++;
        modCount++;
        return null;
    }

