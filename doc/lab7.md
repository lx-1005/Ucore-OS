


## 并发问题是什么？

多线程并发导致对共享资源的竞争，需要通过底层硬件支持或者高层次的抽象（若没有硬件支持也可以实现，只是效率低），实现对临界区的同步/互斥访问

## 同步和互斥？

同步：在多线程并发环境下，协调线程的执行顺序

互斥： 互斥是同步的一种特殊情况，特指在多线程并发环境下，任何时刻都只能有一个线程执行临界区代码


## 解决办法：

1. 底层硬件提供支持
    
* 原子操作：对于硬件原子操作指令（如TS，Exchange，CAS，FAA等），硬件保证了在执行这些原子操作指令期间，不会发生中断或上下文切换，从而确保了原子操作的正确性。
    * 通过**屏蔽中断**或**锁内存总线**（在多核系统中，防止其他处理器同时访问同一内存地址。当一个处理器执行原子操作指令时，其他处理器将被阻塞，直到当前操作完成，从而确保了原子性。） 
    * 总之，硬件架构保证：这些硬件原子操作指令，有些可以在一个时钟周期内完成，有些尽管需要多个时钟周期，但硬件通过屏蔽中断或者锁内存总线的机制保证该指令的原子性

2. 高层次的编程抽象
    
    * 自旋锁
    * 信号量： 资源数目+P/V操作，（当资源数目为0/1时 -> 互斥锁）
    * 条件变量


## 实现同步互斥的底层支撑技术：
    
    屏蔽中断：sti和cli
    
    定时器：将若干个定时器按过期时间升序排列（），每个定时器上睡眠着若干个进程（这些进程的睡眠时间相同），每个时钟中断都会依次递减所有定时器的过期时间，若某个定时器过期时间减为0（一定是第一个），则唤醒睡眠在该定时器上的所有进程，并插入就绪队列，等待被调度
    
    等待队列： 每个等待队列上保存了所有无法进入临界区从而等待该信号量的进程。
             若执行P操作发现sem<0后会进入阻塞态，加入等待队列，并调度另一个进程执行；
             若等到某个进程出临界区时，执行V操作sem>0，会唤醒等待队列上的一个进程，使其进入就绪态，等待被调度


## 信号量的实现：

信号量的数据结构：
```c
typedef struct {
 int value; // 资源数
 wait_queue_t wait_queue; // 该信号量的等待队列
} semaphore_t;
```

V操作（对应UP）：首先关中断，如果该信号量对应的等待队列为空，直接++value，打开中断返回；如果不为空，则唤醒等待队列中的第一个进程，将其从等待队列中删除，最后打开中断返回。
```c
static __noinline void __up(semaphore_t *sem, uint32_t wait_state) {
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        wait_t *wait;
        if ((wait = wait_queue_first(&(sem->wait_queue))) == NULL) {
            sem->value ++;
        }
        else {
            assert(wait->proc->wait_state == wait_state);
            wakeup_wait(&(sem->wait_queue), wait, wait_state, 1);
        }
    }
    local_intr_restore(intr_flag);
}
```

P操作（对应down）： 首先关中断，若当前信号量的value>0, 则--value后打开中断返回；否则表明无法获得信号量，将该进程加入此信号量的等待队列，打开中断，然后调度另一个进程执行
```c
static __noinline uint32_t __down(semaphore_t *sem, uint32_t wait_state) {
    bool intr_flag;
    local_intr_save(intr_flag);
    if (sem->value > 0) {
        sem->value --;
        local_intr_restore(intr_flag);
        return 0;
    }
    wait_t __wait, *wait = &__wait;
    wait_current_set(&(sem->wait_queue), wait, wait_state);
    local_intr_restore(intr_flag);

    schedule();

    local_intr_save(intr_flag);
    wait_current_del(&(sem->wait_queue), wait);
    local_intr_restore(intr_flag);

    if (wait->wakeup_flags != wait_state) {
        return wait->wakeup_flags;
    }
    return 0;
}
```





## 哲学家就餐问题，读者写者问题

* 信号量
* 条件变量和管程



## 内核实现多线程同步/互斥和用户态实现的区别？

以信号量为例，实现基础是原子性的P/V操作，其中开关中断等指令都需要在内核态下运行，因此需要将内核函数封装成系统调用给用户态使用









