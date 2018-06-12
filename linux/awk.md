[TOC]

## Built-In Var
- NR 行号
- NF 每一行的column数
3.  $NF，最后一列值
4.  ​
## Built-In Functions

-   length
-   ​

## printf

`printf(format, value1, value2,...)`

## arithmetic operator

-   \>
-   ==
-   \<
-   &&
-   ||
-   |(NOT)
-   ~匹配正则
-   !~不匹配正则

## Basic

`awk 'pattern{action}' file1 file2 …`

其中`pattern-action`可以是多个

`awk '\$2 > 4 { print \$1 } \$3>6{print \$1}'`分别输出了第二列大于4和第三列大于6的行

## BEGIN and END

分别在第一个文件第一行之前，最后一个文件最后一行之后执行。`BEGIN{}{pattern-action}END{}`

多个不同pattern-action之间可以以`;`隔开

## Counting,sum,averge

```shell
cat at
h	1
o	2
n	3
g	4
j	5
i	6
a	7
n	8
```

```shell
awk 'BEGIN{count=0};$2>1{count+=1};END{printf("char count which val is more than 3: %d", count)}' at
char count which val is more than 3: 7
awk 'END{printf("total char is %d", NR)}' at
total char is 8
awk 'BEGIN{sum=0}{sum+=$2}END{printf("total char val is %d, average char val is %d", sum, sum/NR)}' at
total char val is 36, average char val is 4
```

## concatenation

```shell
awk 'BEGIN{name=""}{name=name $1 ""}END{print name}' at
hongjian
awk 'BEGIN{name=""}{name=name $1 "_"}END{print name}' at
h_o_n_g_j_i_a_n_
```

## Control-Flow Statements

仅能用于action语句

If-else

```shell
cat awk
BEGIN {
    name="";
}
{
    name=name $1 "_";
}
END {
    if (length(name) > 14) {
    	print "name is more than 14"
    } else if (length(name) > 8) {
    	print "name is more than 18"
    } else {
	print "name is less than 8"
    }
}

awk -f awk at
name is more than 14
```

while

```shell
cat money_rate
{
    i = 1;
    while (i <= $3) {
    	printf("the %d year, total money is %.2f\n", i, $1 * (1 + $2) ^ i);
	i++;
    }
}
awk -f money_rate
1000 0.01 5
the 1 year, total money is 1010.00
the 2 year, total money is 1020.10
the 3 year, total money is 1030.30
the 4 year, total money is 1040.60
the 5 year, total money is 1051.01
```

for

```shell
cat money_rate
{
    for (i=1; i<=$3;i++) {
        printf("the %d year, total money is %.2f\n", i, $1 * (1 + $2) ^ i);
    }
}
1000 0.01 5
the 1 year, total money is 1010.00
the 2 year, total money is 1020.10
the 3 year, total money is 1030.30
the 4 year, total money is 1040.60
the 5 year, total money is 1051.01
```

## Array

输出行的倒序

```shell
cat reverse
{
    lines[NR] = $1
}
END {
    i=NR;
    while (i > 0) {
        print lines[i];
        i--;
    }
}

awk -f reverse at
n
a
i
j
g
n
o
h
```

## Rehular Expression(ERE)

匹配所有带n的

```shell
awk '/n/' at
n	3
n	8

awk '/^n$/'
mns
abn
n
n

awk '$1 ~ /^[[:digit:]]{1,2}$/'
123
1
1
2
2
```



