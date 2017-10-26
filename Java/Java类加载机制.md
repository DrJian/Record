##概述
>Java语言的类加载、连接和初始化都是在程序运行期间完成的，这样损失了一些加载时的性能开销，但是为Java应用程序提供了很高的灵活性，动态扩展就是依赖运行期动态加载和动态连接。

##Java为什么可以跨平台
看了<<深入浅出JVM>>之后，所有Java文件会被编译成二进制码，即.class文件，JVM可以处理这些二进制文件，这是问题的主要。

##动态加载过程
1. 加载
2. 连接：验证、准备、解析
3. 初始化

##触发初始化
new,初始化static,调用static，reflect,子类被初始化，虚拟机启动时，执行Main方法的主类。(主动引用)，其他的被动引用不会触发。

<font color=red>常量在编译器被扔入常量池</font>

###加载
1. 类全名获取类的二进制流。
2. 静态结构转换为方法区运行时数据。
3. 生成一个Class对象，作为方法区这个类各种数据的入口。

###连接
1. 验证过程主要是去验证加载进来的文件的合法性，避免不规范或对虚拟机有伤害。
2. 准备阶段为类分配内存并设置类变量的初始值（这里我们说的是类的变量，即static修饰的）。初始值并不是用户指定的值，而是根据类型赋的。例如
```
public static int a = 1;
```
在准备阶段过后，a = 0;如果是final static则准备后，a=1；
3. 对方法和符合做一些解析。

###初始化
这是类加载的最后一步，真正开始执行Java程序代码，也就是前面加载进来的字节码。

**静态代码块只能访问定义在其前面的静态变量，不放访问在其后定义的，但可以赋值**

这里有一个<clinit>方法，它收集了类的静态变量和静态代码块的信息，收集的顺序由在源文件中的出现顺序决定，父类一定先于子类执行<clinit>方法。

##类加载器
在虚拟机中，每一个类都由这个类本身以及它的类加载器来确定它在虚拟机中的唯一性。来自于同一个class文件，但由不同的类加载器加载，这两个类也是不相等的。

###双亲委派模型(推荐类加载方式)
>**Bootstrap ClassLoader->Extension ClassLoader->Application ClassLoader->User ClassLoader**

关于调用类加载器时，会将请求交给父加载器去处理，父加载器处理不了，再由子加载器进行加载。这样做可以避免许多安全问题，例如用户自己写了一个Object类，然后进行加载，如果加载成功，就会天下大乱。以下是ClassLoader类的loadClass方法，可以看到先去调用父类，如果父类找不到，或者没有父类在启动类加载器中也找不到，那么就调用findClss方法去加载，我们可以在findClass中重写。

```java
protected Class<?> loadClass(String name, boolean resolve)
    throws ClassNotFoundException
{
    synchronized (getClassLoadingLock(name)) {
        // First, check if the class has already been loaded
        Class<?> c = findLoadedClass(name);
        if (c == null) {
            long t0 = System.nanoTime();
            try {
                if (parent != null) {
                    c = parent.loadClass(name, false);
                } else {
                    c = findBootstrapClassOrNull(name);
                }
            } catch (ClassNotFoundException e) {
                // ClassNotFoundException thrown if class not found
                // from the non-null parent class loader
            }

            if (c == null) {
                // If still not found, then invoke findClass in order
                // to find the class.
                long t1 = System.nanoTime();
                c = findClass(name);

                // this is the defining class loader; record the stats
                sun.misc.PerfCounter.getParentDelegationTime().addTime(t1 - t0);
                sun.misc.PerfCounter.getFindClassTime().addElapsedTimeFrom(t1);
                sun.misc.PerfCounter.getFindClasses().increment();
            }
        }
        if (resolve) {
            resolveClass(c);
        }
        return c;
    }
}
```
