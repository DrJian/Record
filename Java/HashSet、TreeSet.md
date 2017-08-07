HashSet、TreeSet相对来说比较简单，他们的特点是不可重复，即插入其中的元素不会重复，那么为什么呢？
##<font color=green>HashSet、TreeSet</font>
二者的底层分别是HashMap、TreeMap,所有调用的add、remove等方法，都会转换成去调用对应map下的方法，那么怎么保证元素的唯一性呢？
举个例子看一下，

	public boolean add(E e) {
        return map.put(e, PRESENT)==null;
    }
这是HashSet下的add方法，PRESENT是一个类的成员变量，

	private static final Object PRESENT = new Object();

对于add调用，实际上是将存入的元素当作key存入底层支持的map中，所以一个相同的key在底层map中只会出现一次，这就是原因。

对于其他的差别，去想HashMap和HashSet就可以。