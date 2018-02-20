[TOC]
# 系统级IO

## UNIX_IO

### 文件打开

- 一个应用程序想要打开一个文件，通知内核，内核打开一个文件后，会返回一个非负整数给应用程序，内核自己会维护自己维护这个打开文件的信息，而应用程序只需记住这个整数，它被叫做描述符。
- 对于打开的文件，内核会保持一个文件位置p，初始为0，表示当前文件指针位置相对文件开头位置的偏移量。
- 无论一个进程因为何种原因终止，内核都会关闭所有打开的文件，并释放他们的内存资源。

### 文件

每个linux文件都有一个类型表明自己在系统中的角色：

- regular file包含任意数据。其中应用程序关心文本文件和二进制文件，文本文件通常是只含有ASCII或Unicode字符的普通文件，二进制则是其他文件。
- 目录
- 套接字
- 命名管道，符号链接，字符，块设备等

###系统级文件函数

open()   read()  write()等系统级函数完成文件打开以及读写操作。

使用RIO的文件读写包，可以更加健壮地完成文件读写，支持带缓冲区和不带缓冲区的读写模式。

- 在Linux中，read 和 write 是基本的系统级I/O函数。当用户进程使用read 和 write 读写linux的文件时,进程会从用户态进入内核态，通过I/O操作读取文件中的数据。内核态（内核模式）和用户态（用户模式）是linux的一种机制，用于限制应用可以执行的指令和可访问的地址空间，这通过设置某个控制寄存器的位来实现。进程处于用户模式下，它不允许发起I/O操作，所以它必须通过系统调用进入内核模式才能对文件进行读取。
- 从用户模式切换到内核模式，主要的开销是处理器要将**返回地址（当前指令的下一条指令地址）和额外的处理器状态（寄存器）压入到栈中，这些数据到会被压到内核栈而不是用户栈。另外，一个进程使用系统调用还隐含了一点 调用系统调用的进程可能会被抢占**。当内核代表用户执行系统调用时，若该系统调用被阻塞，该进程就会进入休眠，然后由内核选择一个就绪状态，当前优先级最高的进程运行。另外，即使系统调用没有被阻塞，当系统调用结束，从内核态返回时，若在系统调用期间出现了一个优先级更高的进程，则该进程会抢占使用了系统调用的进程。内核态返回会返回到优先级高的进程，而不是原本的进程。
- 虽然我们可以每次进行读写时都使用系统调用，但这样会增大系统的负担。当一个进程需要频繁调用 `read` 从文件中读取数据时，它便要频繁地在用户态与内核态之间进行切换，极端点地设想一个情景，每次`read`调用都只读取一个字节，然后循环调用read读取n个字节，这便意味着进程要在用户态和内核态之间切换n次，虽然这是一个及其愚蠢的编程方法，但能够毫无疑问说明系统调用的开销。下图是调用`read(int fd, void *buf, size_t count)`读取516,581,760字节，每次read可以读取的最大字节数量（count的值）的不同对CPU的存取效率的影响。
- 这张表的运行结果是基于块大小为4096-byte的ext4文件系统上的，所以可以看到当 BUFFSIZE=4096时，System CPU 几乎达到了最小值，之后块大小若继续增加，System CPU时间减小的幅度很小，甚至还有所增加。这是若 BUFFSIZE 过大，其缓冲区便跨越了不同的块，导致存取效率降低。

#### RIO

- RIO,全称 Robust I/O，即健壮的IO包。它提供了与系统I/O类似的函数接口，在读取操作时，RIO包加入了读缓冲区，一定程度上增加了程序的读取效率。另外，带缓冲的输入函数是线程安全的，这与Stevens的 UNP 3rd Edition(中文版) P74 中介绍的那个输入函数不同。UNP的那个版本的带缓冲的输入函数的缓冲区是以静态全局变量存在，所以对于多线程来说是不可重入的。RIO包中有专门的数据结构为每一个文件描述符都分配了相应的独立的读缓冲区，这样不同线程对不同文件描述符的读访问也就不会出现并发问题（然而若多线程同时读同一个文件描述符则有可能发生并发访问问题，需要利用锁机制封锁临界区）。
- 另外，RIO还帮助我们处理了可修复的错误类型:EINTR。考虑`read`和`write`在阻塞时被某个信号中断，在中断前它们还未读取/写入任何字节，则这两个系统调用便会返回-1表示错误，并将errno置为EINTR。这个错误是可以修复的，并且应该是对用户透明的，用户无需在意read 和 write有没有被中断，他们只需要直到read 和 write成功读取/写入了多少字节，所以在RIO的`rio_read()`和`rio_write()`中便对中断进行了处理。

RIO缓冲区结构

```C
#define RIO_BUFSIZE     4096
typedef struct
{
    int rio_fd;      //与缓冲区绑定的文件描述符的编号
    int rio_cnt;        //缓冲区中还未读取的字节数
    char *rio_bufptr;   //当前下一个未读取字符的地址
    char rio_buf[RIO_BUFSIZE];
}rio_t;
```

基础函数

```c
void rio_readinitb(rio_t *rp, int fd)
/**
 * @brief rio_readinitb     rio_t 结构体初始化,并绑定文件描述符与缓冲区
 *
 * @param rp                rio_t结构体
 * @param fd                文件描述符
 */
{
    rp->rio_fd = fd;
    rp->rio_cnt = 0;
    rp->rio_bufptr = rp->rio_buf;

    return;
}



static ssize_t rio_read(rio_t *rp, char *usrbuf, size_t n)
/**
 * @brief rio_read  RIO--Robust I/O包 底层读取函数。当缓冲区数据充足时，此函数直接拷贝缓
 *                  冲区的数据给上层读取函数；当缓冲区不足时，该函数通过系统调用
 *                  从文件中读取最大数量的字节到缓冲区，再拷贝缓冲区数据给上层函数
 *
 * @param rp        rio_t，里面包含了文件描述符和其对应的缓冲区数据
 * @param usrbuf    读取的目的地址
 * @param n         读取的字节数量
 *
 * @returns         返回真正读取到的字节数（<=n）
 */
{
    int cnt;

    while(rp->rio_cnt <= 0)     
    {
        rp->rio_cnt = read(rp->rio_fd, rp->rio_buf, sizeof(rp->rio_buf));
        if(rp->rio_cnt < 0)
        {
            if(errno != EINTR)  //遇到中断类型错误的话应该进行读取，否则就返回错误
                return -1;
        }
        else if(rp->rio_cnt == 0)   //读取到了EOF
            return 0;
        else
            rp->rio_bufptr = rp->rio_buf;       //重置bufptr指针，令其指向第一个未读取字节，然后便退出循环
    }

    cnt = n;
    if((size_t)rp->rio_cnt < n)     
        cnt = rp->rio_cnt;
    memcpy(usrbuf, rp->rio_bufptr, n);
    rp->rio_bufptr += cnt;      //读取后需要更新指针
    rp->rio_cnt -= cnt;         //未读取字节也会减少

    return cnt;
}


ssize_t rio_readnb(rio_t *rp, void *usrbuf, size_t n)
/**
 * @brief rio_readnb    供用户使用的读取函数。从缓冲区中读取最大maxlen字节数据
 *
 * @param rp            rio_t，文件描述符与其对应的缓冲区
 * @param usrbuf        void *, 目的地址
 * @param n             size_t, 用户想要读取的字节数量
 *
 * @returns             真正读取到的字节数。读到EOF返回0,读取失败返回-1。
 */
{
    size_t leftcnt = n;
    ssize_t nread;
    char *buf = (char *)usrbuf;

    while(leftcnt > 0)
    {
        if((nread = rio_read(rp, buf, n)) < 0)
        {
            if(errno == EINTR)      //其实这里可以不用判断EINTR,rio_read()中已经对其处理了
                nread = 0;
            else 
                return -1;
        }
        leftcnt -= nread;
        buf += nread;
    }

    return n-leftcnt;
}


ssize_t rio_readlineb(rio_t *rp, void *usrbuf, size_t maxlen)
/**
 * @brief rio_readlineb 读取一行的数据，遇到'\n'结尾代表一行
 *
 * @param rp            rio_t包
 * @param usrbuf        用户地址，即目的地址
 * @param maxlen        size_t, 一行最大的长度。若一行数据超过最大长度，则以'\0'截断
 *
 * @returns             真正读取到的字符数量
 */
{
    size_t n;
    int rd;
    char c, *bufp = (char *)usrbuf;

    for(n=1; n<maxlen; n++)     //n代表已接收字符的数量
    {
        if((rd=rio_read(rp, &c, 1)) == 1)
        {
            *bufp++ = c;
            if(c == '\n')
                break;
        }
        else if(rd == 0)        //没有接收到数据
        {
            if(n == 1)          //如果第一次循环就没接收到数据，则代表无数据可接收
                return 0;
            else
                break;
        }
        else                    
            return -1;
    }
    *bufp = 0;

    return n;
}


ssize_t rio_writen(int fd, void *usrbuf, size_t n)
{
    size_t nleft = n;
    ssize_t nwritten;
    char *bufp = (char *)usrbuf;

    while(nleft > 0)
    {
        if((nwritten = write(fd, bufp, nleft)) <= 0)
        {
            if(errno == EINTR)
                nwritten = 0;
            else
                return -1;
        }
        bufp += nwritten;
        nleft -= nwritten;
    }

    return n;
}
```

###  共享文件

#### 组成

**fd 0 1 2默认为标准输入，标准输出，标准错误输出**

Linux系统如何去标记一个文件？描述符表，文件表，v-node表

- 描述符表为进程级别的一个列表，表项由进程打开的文件描述来索引，每一个fd对应文件表中的一个表项。
- 文件表，所有进程共享的一个列表，每个表项记录了文件当前打开位置，文件的引用数，也就是被多少个fd所指向。父进程fork子进程时，子进程会生成一个父进程文件描述符表的副本。可能出现多个文件表中的表项指向同一个v-node表记录。
- v-node，所有进程共享的一个列表，每个表项包含了stat的绝大部分结构。



#### 文件重定向

调用`dup2(int oldFd, int newFd)`直接将oldFd描述符表中的指向文件改变到newFd对应的文件，之后的输出便会写到newFd指向的文件，如果newFd文件已打开，复制完后，会把newFd对应文件关闭。