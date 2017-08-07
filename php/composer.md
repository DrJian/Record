[关于介绍Composer的一篇不错的博文](https://laravel-china.org/topics/1002)

>Composer作为管理包依赖的工具，本身也提供了对于类加载的支持。上面的博文有了对于composer类加载的四种方式的介绍。

今天简单看了一下其加载方式的实现。简单介绍之前，希望大家自己先使用composer构建一次项目依赖。

## 使用composer完成Project依赖管理（mac）

1. 进入项目目录下执行`composer init`，之后根据提示输入一系列东西，当然如果你很懒惰，那就一路enter吧。
2. 看一看你的`composer.json`文件吧，所有的配置我们都会写在里面。

~~~json
{
    "name": "Jian/composer",
    "description": "Jian test composer",
    "type": "project",
    "authors": [
        {
            "name": "Jian",
            "email": "Jian@haha.com"
        }
    ],
    "require": {
		  "laravel/framework": "5.2.*"
    },
    "repositories": {
        "packagist": {
            "type": "composer",
            "url": "https://packagist.phpcomposer.com"
        }
    }
}
~~~
这里我们就简单从配置中的仓库拉取laravel的库，指定版本5.2.*

vendor目录下就是由composer生成的内容，同时如果在composer.json中配置了psr-0 psr-4 classmap files这些类加载方式的话，会生成一个composer目录.

## 看看具体干了什么
 如同上面给到的链接里写到的一样，核心处理类就是 `vendor/composer/autoload_real.php`这个类，它做的事情就是把psr-0，psr-4,classmap以及files四种方式加载的类注册到`vendor/composer/ClassLoader`类下。

>* classMap->ClassLoader的classmap数组中
>* psr-0 psr-4->namespace注册到相应数组
>* files中定义的文件全部放在全局变量$GLOBALS['__composer_autoload_files']中

 上面的类注册后，会执行vendor/composer/ClassLoader类的register方法，将该类下的loadClass方法注册到类加载队列中，之后当new一个新的类的时候，php会在所有注册的类加载函数中进行查找(执行注册进来的方法)。
 
#### loadClass方法
---
执行findFile方法 

1. 如果ClassLoader下的classmap数组中有相应的类，直接返回；如果在missingFiles中有纪录这个类是加载不到的，直接返回false。
2. 如果apcu前缀不为空且在php.ini配置中开启了apc功能，则使用apcu_fetch查询类是否存在
3. 根据文件名，带上文件后缀`.php`在psr0和psr4中进行查找。
4. 如果在第三步之中找到相应class，则在第二步的前提条件下，将类路径借助apcu_add存起来。
5. 如果以上都找不到相应的类，则将类纪录在missFiles数组中。
 