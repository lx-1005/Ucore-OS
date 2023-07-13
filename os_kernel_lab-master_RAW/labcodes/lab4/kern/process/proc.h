#ifndef __KERN_PROCESS_PROC_H__
#define __KERN_PROCESS_PROC_H__

#include <defs.h>
#include <list.h>
#include <trap.h>
#include <memlayout.h>


// process's state in his life cycle
enum proc_state {
    PROC_UNINIT = 0,  // 未初始化的     -- alloc_proc
    PROC_SLEEPING,    // 等待状态       -- try_free_pages, do_wait, do_sleep
    PROC_RUNNABLE,    // 就绪/运行状态   -- proc_init, wakeup_proc,
    PROC_ZOMBIE,      // 僵尸状态       -- do_exit
};

// Saved registers for kernel context switches.
// Don't need to save all the %fs etc. segment registers,
// because they are constant across kernel contexts.
// Save all the regular registers so we don't need to care
// which are caller save, but not the return register %eax.
// (Not saving %eax just simplifies the switching code.)
// The layout of context must match code in switch.S.
struct context { // 保存的上下文寄存器，注意没有eax寄存器和段寄存器
    uint32_t eip;
    uint32_t esp;
    uint32_t ebx;
    uint32_t ecx;
    uint32_t edx;
    uint32_t esi;
    uint32_t edi;
    uint32_t ebp;
};

#define PROC_NAME_LEN               15
#define MAX_PROCESS                 4096
#define MAX_PID                     (MAX_PROCESS * 2)

extern list_entry_t proc_list;

struct proc_struct {
    enum proc_state state;          // 当前进程的状态
    int pid;                        // 进程ID
    int runs;                       // 当前进程被调度的次数
    uintptr_t kstack;               // 内核栈
    volatile bool need_resched;     // 是否需要被调度
    struct proc_struct *parent;     // 父进程
    struct mm_struct *mm;           // 当前进程所管理的虚拟内存块，页表
    struct context context;         // 保存的上下文
    struct trapframe *tf;           // 中断保存的上下文
    uintptr_t cr3;                  // cr3: 页目录表的基址
    uint32_t flags;                 // 当前进程的相关标志
    char name[PROC_NAME_LEN + 1];   // 进程名称（可执行文件名）
    list_entry_t list_link;         // 进程链表
    list_entry_t hash_link;         // 用hash表加快查找pcb的速度
};


#define le2proc(le, member)         \
    to_struct((le), struct proc_struct, member)

extern struct proc_struct *idleproc, *initproc, *current;

void proc_init(void);
void proc_run(struct proc_struct *proc);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);

char *set_proc_name(struct proc_struct *proc, const char *name);
char *get_proc_name(struct proc_struct *proc);
void cpu_idle(void) __attribute__((noreturn));

struct proc_struct *find_proc(int pid);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
int do_exit(int error_code);

#endif /* !__KERN_PROCESS_PROC_H__ */

