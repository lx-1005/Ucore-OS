

[TOC]

d

# 知识点:

## 开机启动的过程?

1. 加电后, CPU的CS:IP寄存器被强制初始化为`0xF000:0xFFF0`，即`0xFFFF0`. 这里是一条长跳转指令:`jmp far f000:e05b`，跳转至BIOS真正的代码。

2. bios的工作:

   * 硬件自检和初始化
* 建立中断向量表, 以中断调用的方式提供基本的I/O功能: 磁盘扇区读写; 键盘输入; 在显示器上显示字符; 检测内存大小;
   * 检查引导设备的内容, 若MBR的末尾两个字分别是魔数`0x55`和`0xaa`，则BIOS认为此扇区中存在可执行的程序，并加载该512字节数据到`0x7c00`，随后跳转至此继续执行。

3. bootloader的工作: 

   - 使能保护模式 & 段机制

     - 开启A20：开启键盘控制器的A20端口, 使全部32条地址线可用，cpu就可以访问4G的内存空间; 开启A20的原因: intel为了兼容旧版本8086
     - 初始化GDT表：设置三个段(null, kernel CS, kernel DS)
     - 开启保护模式：将CR0寄存器的PE(Protected Enable)位置1
   
   * 解析并读取kernel文件: 先从硬盘读取ELF header, 经过校验后, 读取ELF格式的kernel文件并执行, 从此cpu控制权交给os kernel

   




## 为什么不让BIOS直接加载OS kernel?

OS kernel原本存储在磁盘上, 磁盘上的文件系统多种多样, 不可能让BIOS识别所有的文件系统. 因此, BIOS功能非常简单, 无脑把磁盘的第一个扇区读到内存中, 再由bootloader去识别磁盘的文件系统, 并加载OS





## 堆栈?

bootloade设置初始化堆栈位置: ebp=0x0, esp=0x7c00, 随着call指令逐渐形成调用栈

## 中断的处理流程?

* 在产生中断的时刻, 硬件会将被打断程序的上下文信息保存在ring0栈中

![image-20230615175705402](https://gcore.jsdelivr.net/gh/lx-1005/blog-img@main/images/202306151757449.png)

* 根据中断号查IDT, 查出对应的中断门gatedesc
* 根据gatedesc中的段选择子+段内offset, 算出中断处理例程的入口地址, 跳转并执行中断处理例程
  * 根据段选择子查GDT, 查出对应的段描述符
  * 段描述符中的base address + 段内offset, 算出中断处理例程的入口地址
* 中断处理(可能是终止, 重新执行指令等等)结束后, 执行iret指令, 会将ring0栈中保存的信息进行恢复, 从而使被打断程序继续执行













# lab1代码分析



## 操作系统镜像文件 ucore.img 是如何一步一步生成的?

bin/ucore.img
| 生成ucore.img的相关代码为
| $(UCOREIMG): $(kernel) $(bootblock)
|	$(V)dd if=/dev/zero of=$@ count=10000
|	$(V)dd if=$(bootblock) of=$@ conv=notrunc
|	$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc
|
| 为了生成ucore.img，首先需要生成bootblock、kernel
|
|>	bin/bootblock
|	| 生成bootblock的相关代码为
|	| $(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
|	|	@echo + ld $@
|	|	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ \
|	|		-o $(call toobj,bootblock)
|	|	@$(OBJDUMP) -S $(call objfile,bootblock) > \
|	|		$(call asmfile,bootblock)
|	|	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) \
|	|		$(call outfile,bootblock)
|	|	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)
|	|
|	| 为了生成bootblock，首先需要生成bootasm.o、bootmain.o、sign
|	|
|	|>	obj/boot/bootasm.o, obj/boot/bootmain.o
|	|	| 生成bootasm.o,bootmain.o的相关makefile代码为
|	|	| bootfiles = $(call listf_cc,boot) 
|	|	| $(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),\
|	|	|	$(CFLAGS) -Os -nostdinc))
|	|	| 实际代码由宏批量生成
|	|	| 
|	|	| 生成bootasm.o需要bootasm.S
|	|	| 实际命令为
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs \
|	|	| 	-nostdinc  -fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootasm.S -o obj/boot/bootasm.o
|	|	| 其中关键的参数为
|	|	| 	-ggdb  生成可供gdb使用的调试信息
|	|	|	-m32  生成适用于32位环境的代码
|	|	| 	-gstabs  生成stabs格式的调试信息
|	|	| 	-nostdinc  不使用标准库
|	|	|	-fno-stack-protector  不生成用于检测缓冲区溢出的代码
|	|	| 	-Os  为减小代码大小而进行优化
|	|	| 	-I<dir>  添加搜索头文件的路径
|	|	| 
|	|	| 生成bootmain.o需要bootmain.c
|	|	| 实际命令为
|	|	| gcc -Iboot/ -fno-builtin -Wall -ggdb -m32 -gstabs -nostdinc \
|	|	| 	-fno-stack-protector -Ilibs/ -Os -nostdinc \
|	|	| 	-c boot/bootmain.c -o obj/boot/bootmain.o
|	|	| 新出现的关键参数有
|	|	| 	-fno-builtin  除非用__builtin_前缀，
|	|	|	              否则不进行builtin函数的优化
|	|
|	|>	bin/sign
|	|	| 生成sign工具的makefile代码为
|	|	| $(call add_files_host,tools/sign.c,sign,sign)
|	|	| $(call create_target_host,sign,sign)
|	|	| 
|	|	| 实际命令为
|	|	| gcc -Itools/ -g -Wall -O2 -c tools/sign.c \
|	|	| 	-o obj/sign/tools/sign.o
|	|	| gcc -g -Wall -O2 obj/sign/tools/sign.o -o bin/sign
|	|
|	| 首先生成bootblock.o
|	| ld -m    elf_i386 -nostdlib -N -e start -Ttext 0x7C00 \
|	|	obj/boot/bootasm.o obj/boot/bootmain.o -o obj/bootblock.o
|	| 其中关键的参数为
|	|	-m <emulation>  模拟为i386上的连接器
|	|	-nostdlib  不使用标准库
|	|	-N  设置代码段和数据段均可读写
|	|	-e <entry>  指定入口
|	|	-Ttext  制定代码段开始位置
|	|
|	| 拷贝二进制代码bootblock.o到bootblock.out
|	| objcopy -S -O binary obj/bootblock.o obj/bootblock.out
|	| 其中关键的参数为
|	|	-S  移除所有符号和重定位信息
|	|	-O <bfdname>  指定输出格式
|	|
|	| 使用sign工具处理bootblock.out，生成bootblock
|	| bin/sign obj/bootblock.out bin/bootblock
|
|>	bin/kernel
|	| 生成kernel的相关代码为
|	| $(kernel): tools/kernel.ld
|	| $(kernel): $(KOBJS)
|	| 	@echo + ld $@
|	| 	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
|	| 	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
|	| 	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; \
|	| 		/^$$/d' > $(call symfile,kernel)
|	| 
|	| 为了生成kernel，首先需要 kernel.ld init.o readline.o stdio.o kdebug.o
|	|	kmonitor.o panic.o clock.o console.o intr.o picirq.o trap.o
|	|	trapentry.o vectors.o pmm.o  printfmt.o string.o
|	| kernel.ld已存在
|	|
|	|>	obj/kern/*/*.o 
|	|	| 生成这些.o文件的相关makefile代码为
|	|	| $(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,\
|	|	|	$(KCFLAGS))
|	|	| 这些.o生成方式和参数均类似，仅举init.o为例，其余不赘述
|	|>	obj/kern/init/init.o
|	|	| 编译需要init.c
|	|	| 实际命令为
|	|	|	gcc -Ikern/init/ -fno-builtin -Wall -ggdb -m32 \
|	|	|		-gstabs -nostdinc  -fno-stack-protector \
|	|	|		-Ilibs/ -Ikern/debug/ -Ikern/driver/ \
|	|	|		-Ikern/trap/ -Ikern/mm/ -c kern/init/init.c \
|	|	|		-o obj/kern/init/init.o
|	| 
|	| 生成kernel时，makefile的几条指令中有@前缀的都不必需
|	| 必需的命令只有
|	| ld -m    elf_i386 -nostdlib -T tools/kernel.ld -o bin/kernel \
|	| 	obj/kern/init/init.o obj/kern/libs/readline.o \
|	| 	obj/kern/libs/stdio.o obj/kern/debug/kdebug.o \
|	| 	obj/kern/debug/kmonitor.o obj/kern/debug/panic.o \
|	| 	obj/kern/driver/clock.o obj/kern/driver/console.o \
|	| 	obj/kern/driver/intr.o obj/kern/driver/picirq.o \
|	| 	obj/kern/trap/trap.o obj/kern/trap/trapentry.o \
|	| 	obj/kern/trap/vectors.o obj/kern/mm/pmm.o \
|	| 	obj/libs/printfmt.o obj/libs/string.o
|	| 其中新出现的关键参数为
|	|	-T <scriptfile>  让连接器使用指定的脚本
|
| 生成一个有10000个块的文件，每个块默认512字节，用0填充
| dd if=/dev/zero of=bin/ucore.img count=10000
|
| 把bootblock中的内容写到第一个块
| dd if=bin/bootblock of=bin/ucore.img conv=notrunc
|
| 从第二个块开始写kernel中的内容
| dd if=bin/kernel of=bin/ucore.img seek=1 conv=notrunc

## 一个被系统认为是符合规范的硬盘主引导扇区的特征是什么?

从sign.c的代码来看，一个磁盘主引导扇区只有512字节。且
第510个（倒数第二个）字节是0x55，
第511个（倒数第一个）字节是0xAA。

## 从 CPU 加电后执行的第一条指令开始,单步跟踪 BIOS 的执行

改写Makefile文件: 

	lab1-mon: $(UCOREIMG)
		$(V)$(TERMINAL) -e "$(QEMU) -S -s -d in_asm -D $(BINDIR)/q.log -monitor stdio -hda $< -serial null"
		$(V)sleep 2
		$(V)$(TERMINAL) -e "gdb -q -x tools/lab1init"
	debug-mon: $(UCOREIMG)
	
	$(V)$(QEMU) -S -s -monitor stdio -hda $< -serial null &
	$(V)$(TERMINAL) -e "$(QEMU) -S -s -monitor stdio -hda $< -serial null"
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -x tools/moninit"

调用make lab1-mon命令，会运行tools/lab1init的gdb指令， 自动打开qemu和deb窗口， 并且gdb停在0x7c00处， 同时将运行的汇编指令保存在q.log中。
gdb窗口显示0x7c00处执行了cli和cld指令，可以在gdb输入x /30 $pc多显示几条指令， 全部指令保存在bin/q.log中， 可以观察到执行的第一条指令地址是0xFFFFFFF0的ljmp指令（可以对照q.log和bootasm.S和bootmain.c观察指令执行顺序）



## bootloader的工作流程:

1. 从cs:eipc=0x0000:7c00处开始执行, 首先清理环境：包括将flag置0和将段寄存器置0
   	
    ```c
    .code16
      	    cli
      	    cld
      	    xorw %ax, %ax
      	    movw %ax, %ds
    	    movw %ax, %es
      	  	    movw %ax, %ss
   ```


   	
2. 开启A20：通过将A20地址线置于高电位，使全部32条地址线可用，cpu就可以访问4G的内存空间

  ```c
  seta20.1:               # 等待8042键盘控制器不忙
      inb $0x64, %al      # 
      testb $0x2, %al     #
      jnz seta20.1        #
  movb $0xd1, %al         # 发送写8042输出端口的指令
      outb %al, $0x64     #
  
  seta20.2:               # 等待8042键盘控制器不忙
      inb $0x64, %al      # 
      testb $0x2, %al     #
      jnz seta20.1        #
  movb $0xdf, %al     # 打开A20
  outb %al, $0x60     # 
  ```

3. 初始化并加载GDT表：

一个简单的GDT表和其描述符已经静态储存在引导区中，通过lgdt指令载入即可; 初始的gdt表只有三个段： NULL_ASM, 代码段， 数据段。NULL_ASM位于GDT的下标为0处， 代表不可用。代码段和数据段仅做了简单的对等映射，即段起始地址都是0x0，段大小都是4GB，区别是属性不同(读/写/执行权限不同)

```
lgdt gdtdesc # 加载GDT表

gdt: # GTD表的内容: 3个段描述符，一个8字节，大小共0x18
    SEG_NULLASM                                     # null seg，空段
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel, 代码段CS
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel, 数据段DS, 两种段的属性不同

gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1, 即上面的三个段
    .long gdt                                       # address gdt, GDT表的起始地址
```

4. 进入保护模式：通过将cr0寄存器PE flag置1便开启了32位保护模式
   	    movl %cr0, %eax
      	    orl $CR0_PE_ON, %eax
      	    movl %eax, %cr0

通过ljmp更新cs的基地址, 完成从16位实模式到32位保护模式的转变
	ljmp $PROT_MODE_CSEG, $protcseg   # 切换到代码段CS: 0x8（gdt的null段：0x0，CS段：0x8，DS段：0x10）
	.code32
	    protcseg:

5. 设置段寄存器(包括堆栈), 使得在保护模式下可以正确访问数据, C函数就可以使用了

```
# 设置好数据段的地址空间，使得可以用ds,es,fs,gs,ss等寄存器正确的访问数据段内容
movw $PROT_MODE_DSEG, %ax
movw %ax, %ds
movw %ax, %es
movw %ax, %fs
movw %ax, %gs
movw %ax, %ss

# 设置堆栈
movl $0x0, %ebp      # OS的第一个栈帧，ebp：0x0，esp：0x7c00, 对应函数bootmain()
movl $start, %esp    # 栈顶0x7c00（后续压栈时esp会向低地址延伸, 因此不会破坏bootloader代码）
```



6. 调用C函数bootmain()

```
 call bootmain
```



## 分析bootloader加载ELF格式的OS的过程

readsect(): 读取一个扇区

```c
 // 功能: 从设备的第secno扇区读取数据到dst位置
 static void readsect(void *dst, uint32_t secno) {
	waitdisk(); // 等待磁盘准备好
	
 	// 下面四条指令联合制定了扇区号
    // 在这4个字节线联合构成的32位参数中：
    // 29-31位强制设为1
    // 28位(=0)表示访问"Disk 0"
    // 0-27位是28位的偏移量	
    outb(0x1F2, 1);                         // 设置读取扇区的数目为1
    outb(0x1F3, secno & 0xFF);
    outb(0x1F4, (secno >> 8) & 0xFF);
    outb(0x1F5, (secno >> 16) & 0xFF);
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0);
    
	// outb: linux下常用的I/O端口函数
    // outb(): 写入1字节数据
    // 类似的有outw(写入2字节数据), outl(写入4字节数据)
    outb(0x1F7, 0x20);
    waitdisk(); // 等待磁盘准备好
    
    // insl(): 用汇编实现的读磁盘函数
    // 功能： 读取磁盘的指定大小内容到dst位置
	// 幻数/4因为这里以DW为单位
    insl(0x1F0, dst, SECTSIZE / 4);
}
```



readseg(): 简单包装了readsect()，可以从设备读取任意长度的内容。

```c
// 功能：
// 从kernel起始地址偏移offset处开始读count个字节，读到va地址处。
// 因为以扇区为单位读， 因此实际读的内容>=count个字节
static void readseg(uintptr_t va, uint32_t count, uint32_t offset) {
	uintptr_t end_va = va + count;
    va -= offset % SECTSIZE; // 四舍五入到扇区边界

    // 将字节转换为扇区：计算从哪个扇区开始读
    // 加1因为0扇区被引导占用，os kernel的ELF文件从1扇区开始
    uint32_t secno = (offset / SECTSIZE) + 1; 
    for (; va < end_va; va += SECTSIZE, secno ++) {
            readsect((void *)va, secno); // 每次读1个扇区
    }	
}
```

​    


bootmain(): 解析并读入ELF文件, 并执行os kernel
```c
void bootmain(void) {
	// 首先读取ELF的头部
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);
    // ELF头部的e_magic判断是否是合法的ELF文件
    if (ELFHDR->e_magic != ELF_MAGIC) {
        goto bad;
    }

    // 根据ELF头部中记录的信息，将ELF执行文件的各个段读到内存的相应位置
    // ELF头部中记录了需要将elf执行文件加载到哪，即数据段和代码段的位置信息
    // 具体的位置信息（例如代码段和数据段的base address， size等信息）保存在proghdr结构中
    struct proghdr *ph, *eph;
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    eph = ph + ELFHDR->e_phnum;

    // 将ELF执行文件读入内存
    for (; ph < eph; ph ++) {
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    }

    // 根据ELF头部储存的入口信息，找到内核的入口并执行, 即kern/init/init.c的kern_init()
    // 通过查看obj/bootbolck.asm，bin/q.log, obj/kernel.asm，可以看到内核入口是0x100000, 对应ker_init()
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();
    
    // 若不是合法elf文件，则在此处死循环
    bad: 
        outw(0x8A00, 0x8A00);
        outw(0x8A00, 0x8E00);
        while (1);
}
```



## 实现函数调用堆栈跟踪函数

call指令：先从右往左将参数入栈，返回地址(call指令的下一条指令的地址)入栈，ebp入栈，再将ebp指向到esp的位置
ss:ebp指向caller的ebp，可以沿着调用链依次得到所有调用函数的栈帧位置。
ss:ebp+4指向返回地址(即caller调用该函数时的eip())
ss:ebp+8等是（可能的）参数, csapp上写的前6个参数有专门的寄存器存放，超出6个的参数才入栈。



print_stackframe(): 打印栈帧信息

```c
// 功能: 沿着调用栈, 打印栈帧位置信息
void print_stackframe(void) {
    // ebp: 当前栈帧的栈底位置;
    // eip: 当前函数的下条指令的地址
    // (uint32_t*)ebp： caller的ebp
    // (uint32_t*)ebp + 1： caller的返回地址
    // (uint32_t*)ebp + 2： 被call函数的参数
    uint32_t ebp = read_ebp(), eip = read_eip(); 
    
    // 倒推caller的栈帧位置
    // OS的第一个栈帧0x0是函数bootmain()
    // 限制最多打印STACKFRAME_DEPTH层栈帧信息
    int i, j;
    for (i = 0; ebp != 0 && i < STACKFRAME_DEPTH; i ++) { 
        cprintf("ebp:0x%08x eip:0x%08x args:", ebp, eip);
        uint32_t *args = (uint32_t *)ebp + 2; 
        for (j = 0; j < 4; j ++) {
            cprintf("0x%08x ", args[j]);
        }
        cprintf("\n");
        print_debuginfo(eip - 1);

        // 将当前栈帧的ebp当做指针，拿到caller的ebp和eip
        ebp = ((uint32_t *)ebp)[0];
        eip = ((uint32_t *)ebp)[1];
	}
}
```

## 中断相关的代码流程

* kern/init/kern_init()/pic_init(): 初始化8259A中断控制器, 它的作用是根据不同外设生成不同的中断号
* kern/init/kern_init()/idt_init(): 初始化IDT
* kern/init/kern_init()/clock_init(): 初始化时钟中断
* kern/init/kern_init()/intr_enable(): 开启中断(之前bootloader在boot/bootasm.S的start处通过cli指令关闭了中断)
* 中断处理函数(根据中断号处理不同中断): tools/vector.c -> kern/trap/vectors.S -> kern/trap/trapentry.S -> kern/trap/trap.c



## 中断向量表中一个表项占多少字节？中断处理例程的入口在哪里？

* 中断向量表的一个表项占用8字节

* 根据gdt[i]中的段选择子和段内offset字段, 可以算出中断号 i 对应的中断处理程序的入口地址:
   * 段选择子*8+GDT的起始地址 -> 段描述符
   * 段描述符中的base address + 段内offset -> 中断处理例程入口
   * 备注: GDTR保存了GDT的位置(起始地址和表大小)

* 中断, 异常, 系统调用共用一个IDT, 其中系统调用只占用一个中断号, 具体的系统调用函数保存在系统调用表中

## IDT的生成, 初始化, 以及不同中断的处理流程?

* 生成IDT:

vectors.S 文件通过 vectors.c 自动生成, 其中定义了256个中断的**入口程序**(push两个必要的参数)和**入口地址**(统一跳转到__alltraps处进行处理), 保存在vectors[]中. 



* 初始化: 

  在kern/trap/trap.c的idt_init()中对struct gatedesc idt[256]完成了初始化, 具体代码流程如下:

```c
extern uintptr_t __vectors[]; // 声明vectors.S中定义的__vectors[256]

// 使用SETGATE宏依次填写idt[i]
int i;
for (i = 0; i < sizeof(idt) / sizeof(struct gatedesc); i ++) { 
    SETGATE(idt[i], 0, GD_KTEXT, __vectors[i], DPL_KERNEL);
}
SETGATE(idt[T_SWITCH_TOK], 0, GD_KTEXT, __vectors[T_SWITCH_TOK], DPL_USER);

// 加载IDT
lidt(&idt_pd);
```



* 中断处理的具体代码流程:

1. 产生中断后，CPU 跳转到相应的中断处理入口 (vectors)，并在桟中压入相应的 error_code（是否存在与异常号相关） 以及 trap_no，然后跳转到 __alltraps 函数入口
2. 所有中断都统一调用__alltraps处理, 首先在栈中保存被打断程序的trap frame结构(主要是各种寄存器), 设置 kernel (内核) 的数据段寄存器，最后压入 esp，作为 trap 函数参数(struct trapframe * tf) 并跳转到中断处理函数 trap() 处
3. trap() -> trap_dispatch(),  具体操作如下:

```c
// 功能: 根据中断号处理不同中断, 支持键盘, 时钟, 串口
static void trap_dispatch(struct trapframe *tf) {
    char c;

    switch (tf->tf_trapno) { // 根据中断号处理不同中断
        case IRQ_OFFSET + IRQ_TIMER:
            // 时钟中断: ticks+=1, 且每过100个周期打印TICK_NUM信息
            ticks ++;
            if (ticks % TICK_NUM == 0) {
                print_ticks();
            }
            break;
        case IRQ_OFFSET + IRQ_COM1:
            // 串口中断: 显示收到的字符
            c = cons_getc();
            cprintf("serial [%03d] %c\n", c, c);
            break;
        case IRQ_OFFSET + IRQ_KBD:
            // 键盘中断: 显示收到的字符
            c = cons_getc();
            cprintf("kbd [%03d] %c\n", c, c);
            break;
        case T_SWITCH_TOU:
            // 切换到user态
            if (tf->tf_cs != USER_CS) {
                switchk2u = *tf;
                switchk2u.tf_cs = USER_CS;
                switchk2u.tf_ds = switchk2u.tf_es = switchk2u.tf_ss = USER_DS;
                switchk2u.tf_esp = (uint32_t)tf + sizeof(struct trapframe) - 8;

                // 设置EFLAGS, 确保能在用户台态下正常使用I/O
                // 如果当前任务的CPL>IOPL, cpu会产生一个一般保护
                switchk2u.tf_eflags |= FL_IOPL_MASK;

                // 设置内核栈(临时的, 这样做不安全), 以便当从用户态->内核态时, 可以找到正确的栈位置 
                // todo: 保存用户栈还是内核栈? UtoK时保存还是KtoU时保存?
                *((uint32_t *)tf - 1) = (uint32_t)&switchk2u;
            }
            break;
        case T_SWITCH_TOK:
            // 切换到kernel态
            if (tf->tf_cs != KERNEL_CS) {
                tf->tf_cs = KERNEL_CS;
                tf->tf_ds = tf->tf_es = KERNEL_DS;
                tf->tf_eflags &= ~FL_IOPL_MASK;
                switchu2k = (struct trapframe *)(tf->tf_esp - (sizeof(struct trapframe) - 8));
                memmove(switchu2k, tf, sizeof(struct trapframe) - 8);
                *((uint32_t *)tf - 1) = (uint32_t)switchu2k;
            }
            break;
        case IRQ_OFFSET + IRQ_IDE1:
        case IRQ_OFFSET + IRQ_IDE2:
            /* do nothing */
            break;
        default:
            // 若为其他中断且产生在内核状态，则挂起系统
            if ((tf->tf_cs & 3) == 0) {
                print_trapframe(tf);
                panic("unexpected trap in kernel.\n");
            }
    }
}
```

4. trap()调用结束后, 通过 ret 指令返回到 alltraps 执行过程; 从栈中恢复所有寄存器的值; 调整 esp 的值：跳过栈中的 trap_no 与 error_code，使esp指向中断返回 eip，通过 iret 调用恢复 cs、eflag以及 eip，继续执行。

## 增加syscall功能，即增加一用户态函数（可执行一特定系统调用：获得时钟计数值）

```c
// todo: 不太懂

当内核初始完毕后，可从内核态返回到用户态的函数，而用户态的函数又通过系统调用得到内核态的服务

在idt_init中，将用户态调用SWITCH_TOK中断的权限打开。
	SETGATE(idt[T_SWITCH_TOK], 1, KERNEL_CS, __vectors[T_SWITCH_TOK], 3);
	
在trap_dispatch中，将iret时会从堆栈弹出的段寄存器进行修改
对TO User:
    tf->tf_cs = USER_CS;
    tf->tf_ds = USER_DS;
    tf->tf_es = USER_DS;
    tf->tf_ss = USER_DS;																																																							
对TO Kernel:
    tf->tf_cs = KERNEL_CS;
    tf->tf_ds = KERNEL_DS;
    tf->tf_es = KERNEL_DS;
    
在lab1_switch_to_user中，调用T_SWITCH_TOU中断。
注意从中断返回时，会多pop两位，并用这两位的值更新ss,sp，损坏堆栈。
所以要先把栈压两位，并在从中断返回后修复esp。
	asm volatile (
	    "sub $0x8, %%esp \n"
	    "int %0 \n"
	    "movl %%ebp, %%esp"
	    : 
	    : "i"(T_SWITCH_TOU)
	);

在lab1_switch_to_kernel中，调用T_SWITCH_TOK中断。
注意从中断返回时，esp仍在TSS指示的堆栈中。所以要在从中断返回后修复esp。
	asm volatile (
	    "int %0 \n"
	    "movl %%ebp, %%esp \n"
	    : 
	    : "i"(T_SWITCH_TOK)
	);

但这样不能正常输出文本。根据提示，在trap_dispatch中转User态时，将调用io所需权限降低。
	tf->tf_eflags |= 0x3000;
```






