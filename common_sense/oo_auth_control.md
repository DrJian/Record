# 面向对象之权限控制 

>##<font color='green'>背景</font>

最近在公司做code review的时候，帮我进行code review的同学，指出我一个类应该使用private修饰，而不是public，我不以为意，回了一句，私有不就是不能继承么，然后，两个老程序员瞬间投来异样之眼神，完蛋，说错话了，简直丢人，利用周六的时间，想想这个面向对象权限控制的问题。

## class

这里说`public、private、protected`都是针对类来说的。`php`和`java`都只支持多继承，java不声明的情况下，默认还有一个包权限，同一个包内拥有访问权限。

### public (公有)

* 可被继承，可以通过类的对象调用
* 类内可以被调用

### private (私有)

* 不可继承，不可通过类的对象调用
* 类内可以调用

### protected

* 可被继承，不可通过类的对象调用
* 类内可以调用

## interface

鉴于interface使用场景，php这里规定interface内部所有方法必须为公有属性(默认为abstract)，属性与类中常量相同(const),接口支持多重继承。

```php
<?php

interface demo {

    const VALUE = 1;

    public function demo(array $a, ObjectClass $class, callable $call);
}
```

### Java中接口使用

变量必须为static final类型，方法也为public abstract

```java
public interface demo{
    
    public static final value = 1;
    
    public abstract void get() {
        return;
    }
}
```

## 严格使用好权限有哪些好处呢

* 很简单，我们在梳理一个方法的时候，比如迁移或者重新编写旧的代码的时候，如果发现这个方法是private的，那么只需要整理一下这个方法在本类内部的使用，这样就不必考虑别的地方的调用。如果是public那么可能就需要打日志或者怎么样去做统计了。protected就不多说了。
* 定义好方法的暴露性之后，可以保护好需要保护的属性以及方法，这些都很重要。


别的以后踩坑了再总结。