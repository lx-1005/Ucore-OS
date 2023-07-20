

## 调度的时机：

* 一个进程从就绪动态变成阻塞态
* 进程退出了
* 进程的时间片用完了，在时钟中断弹出trapframe之前，检测current->need_resched=1则schedule()

## 调度需要考虑的问题：

* 选择哪个进程/线程？
* 选择哪个核？

## ucore的调度框架

![img_5.png](img_5.png)

```cpp
struct sched_class {
    const char *name; // the name of sched_class
    void (*init)(struct run_queue *rq); // Init the run queue
    void (*enqueue)(struct run_queue *rq, struct proc_struct *proc); // put the proc into runqueue, and this function must be called with rq_lock
    void (*dequeue)(struct run_queue *rq, struct proc_struct *proc); // get the proc out runqueue, and this function must be called with rq_lock
    struct proc_struct *(*pick_next)(struct run_queue *rq); // choose the next runnable task
    void (*proc_tick)(struct run_queue *rq, struct proc_struct *proc); // dealer of the time-tick
};
```


## 抢占性：

用户进程是可抢占的；

内核执行是不可抢占的；


## 调度算法： 

* **RR**(Round Robin, 即时间片轮询算法)：
RR调度算法的调度思想 是让所有runnable态的进程分时轮流使用CPU时间。RR调度器维护当前runnable进程的有序运行队列。当前进程的时间片用完之后，调度器将当前进程放置到运行队列的尾部，再从其头部取出进程进行调度。RR调度算法的就绪队列在组织结构上也是一个双向链表，只是增加了一个成员变量，表明在此就绪进程队列中的最大执行时间片。而且在进程控制块proc_struct中增加了一个成员变量time_slice，用来记录进程当前的可运行时间片段。这是由于RR调度算法需要考虑执行进程的运行时间不能太长。在每个timer到时的时候，操作系统会递减当前执行进程的time_slice，当time_slice为0时，就意味着这个进程运行了一段时间（这个时间片段称为进程的时间片），需要把CPU让给其他进程执行，于是操作系统就需要让此进程重新回到rq的队列尾，且重置此进程的时间片为就绪队列的成员变量最大时间片max_time_slice值，然后再从rq的队列头取出一个新的进程执行。

* **多级反馈队列**：

  * 对每个优先级设置1个就绪队列，优先级越高，该队列中进程每次执行的时间片越长；对于新创建的进程，我们将它放到最高优先级的就绪队列去执行，若一个进程被调度很多次了还没执行完（可以设置一个阈值），说明可能是个I/O密集型进程，它对CPU的利用率低，那么将它降低一个优先级。

  * 如果按照优先级，等到高优先级任务结束再开始下一个优先级队列，那么很大可能产生饥饿。因此，可以为每个队列设置一个max_wait_time，表示该队列中所有进程被调度的时间，当达到某一个阈值时，就开始调度更低一级的队列



* **Stride Scheduling**：RR为每个就绪态的进程分配相等的时间片，但这太过公平，实际上高优先级进程理应得到更长的时间片。

  * 特点：
  
        实现简单
       
        可控性：可以证明Stride Scheduling对进程的调度次数正比于其优先级
      
        确定性：在不考虑计时器事件的情况下，整个调度机制都是可预知和重现的。
  * 实现：小顶堆
  
        每个进程被调度后，执行的时间片是固定的
        
        对每个就绪进程设置一个stride和pass，其中stride初始化为进程的优先级（优先级别高，值越小），pass初始化为INT_MAX/priority，其中INT_MAX是一个常数，priority是进程的优先级，可以证明为每个进程分配的时间和其优先级成正比。
        
        每次从就绪队列中选择stride最小的进程，然后将该进程的stride+=pass，该进程执行一个固定大小的时间片后，继续选择stride最小的
        
        为了防止stride过大发生整数溢出，需要定期重置stride
        

* **linux CFS**(完全公平调度算法)：为每个进程设置一个虚拟时钟，CFS调度器总是选择虚拟时钟最小的的进程来运行。CFS的思想就是让每个进程的vruntime互相追赶，而每个调度实体的vruntime增加速度不同，优先级越高的进程权重越大，vruntime增加的越慢，这样就能获得更多的cpu执行时间，进而实现进程调度上的平衡。
    用红黑树实现，按每个进程的bruntime维护大小关系。


