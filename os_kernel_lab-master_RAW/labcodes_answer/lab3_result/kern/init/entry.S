#include <mmu.h>
#include <memlayout.h>

# 逻辑地址-KERNBASE=物理地址
#define REALLOC(x) (x - KERNBASE)

# 主要工作： 开启页机制
.text
.globl kern_entry
kern_entry:
    # 将一级页表 __boot_pgdir （页目录表PDT）的物理基地址加载进%cr3寄存器中
    movl $REALLOC(__boot_pgdir), %eax
    movl %eax, %cr3

    # 启动页机制: 设置%cr0寄存器中PE、PG、AM、WP、NE、MP位，关闭TS 与EM 位
    # PE(Protection Enable): 启动保护模式，默认只是打开分段。
    # OG(Paging): 设置分页标志。只有PE和PG位同时置位，才能启动分页机制。
    # WP(Write Protection): 当该位为1时，CPU会禁止ring0代码向read only page写入数据。这个标志位主要与写时复制有关系。
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0

    # 更新eip的值: 将eip从物理地址“修改”为虚拟地址。
    # 在修改该了PE位之后程序必须立刻使用一条jmp指令，以刷新处理器执行管道中已经获取的不同模式下的任何指令。
    # now, eip = 0x1.....
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:

    # unmap va 0 ~ 4M, it's temporary mapping
    # 一级页表将虚拟内存中的两部分地址KERNBASE+(0-4M) 与 (0-4M) 暂时都映射至物理地址 (0-4M) 处
    # 因为当%cr0寄存器一旦设置，则分页机制立即开启。此时这部分具有相同地址的代码在分页和未分页之间起着桥梁的作用。
    # 无论是否开启分页机制，这部分代码都必须具有相同的地址。
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # 准备kernel stack
    # set ebp, esp
    movl $0x0, %ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
    # now kernel stack is ready , call the first C function
    call kern_init

# should never get here
spin:
    jmp spin

// 全局数组bootstack作为内核栈，大小为2个物理页
// 之后内核可以使用的内核栈只有这一个，中断处理程序可能会从高地址开始，向下覆盖ring3的栈数据。这个漏洞可能是因为未完全实现的内存管理机制所导致的。
.data
.align PGSIZE
    .globl bootstack
bootstack:
    .space KSTACKSIZE
    .globl bootstacktop
bootstacktop:

# kernel builtin pgdir an initial page directory (Page Directory Table, PDT).
# These page directory table and page table can be reused!
.section .data.pgdir
.align PGSIZE
__boot_pgdir:
.globl __boot_pgdir
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # pad to PDE of KERNBASE
    # map va KERNBASE + (0 ~ 4M) to pa 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # pad to PGSIZE

.set i, 0
__boot_pt1:
.rept 1024
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr

