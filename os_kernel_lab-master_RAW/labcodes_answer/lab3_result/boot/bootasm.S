#include <asm.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG,        0x8                     # kernel code segment selector
.set PROT_MODE_DSEG,        0x10                    # kernel data segment selector
.set CR0_PE_ON,             0x1                     # protected mode enable flag
.set SMAP,                  0x534d4150

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts, cli and sti instruction are opposite
    cld                                             # String operations increment

    # Set up the important data segment registers (DS, ES, SS)
    xorw %ax, %ax                                   # Segment number zero
    movw %ax, %ds                                   # -> Data Segment
    movw %ax, %es                                   # -> Extra Segment
    movw %ax, %ss                                   # -> Stack Segment

    # Enable A20: then cpu can access to 4GB address space
    #  For backwards compatibility with the earliest PCs, physical
    #  address line 20 is tied low, so that addresses higher than
    #  1MB wrap around to zero by default. This code undoes this.
seta20.1:
    # 读取0x64端口: 读Status Register
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al                                 # 读取到2则表明缓冲区中没有数据
    jnz seta20.1

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60

/*                                                                                   */
# 下面这部分代码执行完成后，通过BIOS中断中获得的内存分布信息以结构体e820map的形式写入至物理0x8000地址处。
# 稍后ucore的page_init函数会访问该地址并处理所有的物理内存信息。
probe_memory:
    movl $0, 0x8000   # 初始化，向内存地址0x8000，即uCore结构e820map中的成员nr_map中写入0
    xorl %ebx, %ebx   # 初始化%ebx为0，这是int 0x15的其中一个参数
    movw $0x8004, %di # 初始化%di寄存器，使其指向结构e820map中的成员数组map
start_probe:
    movl $0xE820, %eax  # BIOS 0x15中断的子功能编号 %eax == 0xE820
    movl $20, %ecx    # 存放地址范围描述符的内存大小，至少20
    movl $SMAP, %edx  # 签名, %edx == 0x534D4150h("SMAP"字符串的ASCII码)
    int $0x15     # 调用0x15中断
    jnc cont      # 如果该中断执行失败，则CF标志位会置1，此时要通知UCore出错
    movw $12345, 0x8000 # 向结构e820map中的成员nr_map中写入特殊信息，报告当前错误
    jmp finish_probe    # 跳转至结束，不再探测内存
cont:
    addw $20, %di   # 如果中断执行正常，则目标写入地址就向后移动一个位置
    incl 0x8000     # e820::nr_map++
    cmpl $0, %ebx   # 执行中断后，返回的%ebx是原先的%ebx加一。如果%ebx为0，则说明当前内存探测完成
    jnz start_probe
finish_probe:
/*                                                                                   */

    # Switch from real to protected mode, using a bootstrap GDT
    # and segment translation that makes virtual addresses
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
    # use lgdt instruction 加载全局描述符表: (Simple segment mechanism for 1v1: 对等映射)
    # bootloader在启动保护模式前，会设置一个临时GDT以便于进入CPU保护模式后的bootloader和uCore所使用
    lgdt gdtdesc
    movl %cr0, %eax
    orl $CR0_PE_ON, %eax
    movl %eax, %cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.
    ljmp $PROT_MODE_CSEG, $protcseg

.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS
    movw %ax, %gs                                   # -> GS
    movw %ax, %ss                                   # -> SS: Stack Segment

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    movl $start, %esp
    
    
    call bootmain # call the first function: bootmain()
spin: # If bootmain returns (it shouldn't), loop.
    jmp spin

.data
# Bootstrap GDT: 3 segments(null, CS, DS)
.p2align 2                                          # force 4 byte alignment
gdt:
    SEG_NULLASM                                     # null seg
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel

# 全局描述符表gdt的起始地址和大小:
gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1
    .long gdt                                       # address gdt
