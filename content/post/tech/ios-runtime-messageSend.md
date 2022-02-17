---
title: "iOS 底层学习Runtime之消息转发"
author: "LWX"
cover: "/images/cover.jpg"
tags: ["iOS", "runtime", "messageSend"]
date: 2022-02-17T12:11:39+08:00
draft: false
---

本篇主要通过对ios 底层库 objc（runtime）的探究，浅析OC中消息转发的过程





### 1. oc 中的方法调用是如何转化成消息的？

我们熟知的OC中的方法调用是通过方括号的，如下：

``` objective-c
[instance1 testMsgSend]
```
底层是将这种调用方式转化成消息机制了，这一步是依赖于编译器的，接下来我们通过clang的 -rewrite-objc 来看下编译成C++代码的结果。

​	main.m 文件内容

``` objective-c
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "LWXClass.h"


int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
        
        LWXClass *instance1 = [[LWXClass alloc] init];
        [instance1 testMsgSend];
    
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
```

下面我们通过clang将.m文件编译成C++文件：

``` shell
xcrun -sdk iphonesimulator clang -rewrite-objc main.m
```

编译后的main.cpp 文件内容：

``` C++
int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        appDelegateClassName = NSStringFromClass(((Class (*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("AppDelegate"), sel_registerName("class")));

        LWXClass *instance1 = ((LWXClass *(*)(id, SEL))(void *)objc_msgSend)((id)((LWXClass *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("LWXClass"), sel_registerName("alloc")), sel_registerName("init"));
        ((void (*)(id, SEL))(void *)objc_msgSend)((id)instance1, sel_registerName("testMsgSend"));

    }
    return UIApplicationMain(argc, argv, __null, appDelegateClassName);
}
```

通过重写后的C++文件，我们可以清楚的看到，方法调用的地方，都被编成了 objc_msgSend
从官方下载了[objc4-818.2](https://opensource.apple.com/tarballs/objc4/) 的源码，在其中的message.h中找到了 objc_msgSend 的定义

``` C
OBJC_EXPORT void
objc_msgSend(void /* id self, SEL op, ... */ )
    OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0);
```

实际使用就类似于下面 

``` C
objc_msgSend(receiver, SEL)
```

既然方法调用编译后会被转成消息发送，那么我们可不可以直接直接调用objc_msgSend来发送我们的消息呢？
肯定可以啊，我们尝试下将上面的.m文件修改为使用消息发送来处理

``` objective-c
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "LWXClass.h"
#import <objc/message.h>


int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
        
        LWXClass *instance1 = [[LWXClass alloc] init];
//        [instance1 testMsgSend];
        objc_msgSend(instance1, @selector(testMsgSend))
    
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
```

引入 `#import <objc/message.h>`, 将方法修改为 `objc_msgSend(instance1, @selector(testMsgSend))`, 这样就行了吗？编译一下发现会报错：

	error: too many arguments to function call, expected 0, have
		objc_msgSend(instance1, @selector(testMsgSend));

这里需要修改个编译选项，关闭objc_msgSend的stric check:

![关闭 objc_msgSend Stric Check](/post/tech/objc_msgSend_buildsetting.png)


### 2. objc_msgSend 的底层原理