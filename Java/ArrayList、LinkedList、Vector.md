集合类是Java中使用率比较高的类，平常总是会看源码，但看了又会忘记，今天专门记录一下，源码版本是JDK1.8的，本篇博客介绍的内容有ArrayList、LinkedList、Vetor、SynchronizedList、Set、Map

##<font color=green>ArrayList</font>
ArrayList可以理解为数组，平常的使用率很高
###<font color=blue>指定初始化容量大小</font>
如果new的时候指定大小，那么按用户指定的大小进行初始化容量
###<font color=blue>未指定初始化容量大小</font>
默认初始化大小

	private static final int DEFAULT_CAPACITY = 10;
我们结合源代码来查看一下

	public ArrayList() {
	this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
	}
被初始化时，赋值右边的是一个空的对象数组。如下，

	private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

看一眼add函数，看看在它内部到底发生了什么。
	
	public boolean add(E e) {
        ensureCapacityInternal(size + 1);  // Increments modCount!!
        elementData[size++] = e;
        return true;
    }
看到这里第一步调用一个方法，这里是在对容量做一个检查，我们去看一眼

	private void ensureCapacityInternal(int minCapacity) {
        if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
            minCapacity = Math.max(DEFAULT_CAPACITY, minCapacity);
        }

        ensureExplicitCapacity(minCapacity);
    }
有没有看到第一行的话，elementData在默认初始化过程中被赋值为默认空对象数组，size的初值是0，所以这里会将其初始化为10

###<font color=blue>扩容策略</font>
从代码中可以看出，容量扩充一半

	int oldCapacity = elementData.length;
    int newCapacity = oldCapacity + (oldCapacity >> 1);


##<font color=green>LinkedList</font>
与ArrayList相对应，这是一个链表。
链表的每一个子部分都是一个节点，也就是<font color = blue>Node</font>
下面是Node的结构，可见是一个双向的。
	
    private static class Node<E> {
        E item;
        Node<E> next;
        Node<E> prev;

        Node(Node<E> prev, E element, Node<E> next) {
            this.item = element;
            this.next = next;
            this.prev = prev;
        }
    }

对于链表来说，它不需要初始化容量，每增加一个新的节点，只需要将其加在链尾即可，当然也可以选择加在链首，这由用户如何调用封装好的函数决定。JDK开发人员还为我们封装了许多方法，需要可以直接调用。

##<font color=green>LinkedList与ArrayList对比</font>
|ArrayList|LinkedList
----|------|----
中间添加/删除|效率低|效率高
查找	|大部分情况下快，可以指定位置直接访问|慢，从链表头开始


#<font color=red>Vector</font>
---
Vector自JDK1.0开始就出现了。
<font color=bray size = 3>与ArrayList相比，最大的特点就是更加安全，在添加删除等操作时，加上了synchronized关键字，保证了操作的同步性。</font>
###<font color=blue>指定初始化容量大小，扩容策略</font>
如果new的时候指定大小，那么按用户指定的大小进行初始化容量，并且用户可以指定扩容大小。
下面我们看一下扩容函数grow的内容

	int oldCapacity = elementData.length;
       int newCapacity = oldCapacity + ((capacityIncrement > 0 ?  capacityIncrement : oldCapacity);

这里的变量<font color=red>capacityIncrement</font>是用户可以在显示初始化Vector对象时，用户设定 的一个扩容数，我们可以看一眼代码，

	public Vector(int initialCapacity, int capacityIncrement)
我们可以看到这里是可以由用户指定的
###<font color=blue>未指定初始化容量大小</font>
那么如果用户不去指定初始化容量的大小，初始化容量为10，默认会扩容为原容量的两倍。

<font size=3 color=bray>在不需要保证同步性操作的情况下，普通的ArrayList即可满足需求。</font>

##SynchronizedList、Set、Map
在Collectiions类的下面有静态的线程安全的List、Set、Map内部静态类，我们来看看其中一个

	public E get(int index) {
            synchronized (mutex) {return list.get(index);}
        }
        public E set(int index, E element) {
            synchronized (mutex) {return list.set(index, element);}
        }
        public void add(int index, E element) {
            synchronized (mutex) {list.add(index, element);}
        }
        public E remove(int index) {
            synchronized (mutex) {return list.remove(index);}
        }
我们可以看到这里上是将所有的涉及到数据的操作，没贴出来的还有equals操作，都使用了synchronized代码块，显式地上锁，这里用户可以在获取时传入某对象锁，默认使用其本身。