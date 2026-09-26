OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM0 (rwx) : ORIGIN = 0x80000000, LENGTH = 0x00008000
    RAM1 (rwx) : ORIGIN = 0x90000000, LENGTH = 0x00000400
}

SECTIONS
{
	.text :
	{
		__text_begin = .;
		*(.init)
		*(.text*)
		. = ALIGN(4);
		__text_end = .;
	} > RAM0

	.rodata :
	{
        __rodata_begin = .;
		*(.rodata*)
		. = ALIGN(4);
		__rodata_end = .;
	} > RAM0

	.data :
	{
		__data_begin = .;
		*(.data*)
		*(.eh_frame*)
		. = ALIGN(4);
		__data_end = .;
	} > RAM0

	.bss :
	{
		__bss_begin = .;
		*(.bss*)
		*(.sbss*)
		. = ALIGN(4);
		__bss_end = .;
	} > RAM0

	.sdata : 
	{
		__sdata_begin = .;
		*(.sdata*)
		. = ALIGN(4);
		__sdata_end = .;
	} > RAM0

	__global_pointer$ = __sdata_begin + 0x800;

	__stack_top = ORIGIN(RAM0) + LENGTH(RAM0);
	__end = .;

	.ram1 (NOLOAD) :
	{
		__ram1_begin = .;
		*(.ram1*)
		. = ALIGN(4);
		__ram1_end = .;
	} > RAM1

	/DISCARD/ :
	{
		*(.comment)
		*(.debug*)
		*(.riscv.attributes)
	}
}