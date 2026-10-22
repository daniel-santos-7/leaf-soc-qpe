OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM0 (rwx) : ORIGIN = 0x80000000, LENGTH = 0x00000400
    RAM1 (rwx) : ORIGIN = 0x90000000, LENGTH = 0x00008000
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
	} > RAM1

	.rodata :
	{
        __rodata_begin = .;
		*(.rodata*)
		. = ALIGN(4);
		__rodata_end = .;
	} > RAM1

	.data :
	{
		__data_begin = .;
		*(.data*)
		*(.eh_frame*)
		. = ALIGN(4);
		__data_end = .;
	} > RAM1

	.bss :
	{
		__bss_begin = .;
		*(.bss*)
		*(.sbss*)
		. = ALIGN(4);
		__bss_end = .;
	} > RAM1

	.sdata : 
	{
		__sdata_begin = .;
		*(.sdata*)
		. = ALIGN(4);
		__sdata_end = .;
	} > RAM1

	__global_pointer$ = __sdata_begin + 0x800;

	__stack_top = ORIGIN(RAM1) + LENGTH(RAM1);
	__end = .;

	.ram0 (NOLOAD) :
	{
		__ram0_begin = .;
		*(.ram0*)
		. = ALIGN(4);
		__ram0_end = .;
	} > RAM0

	/DISCARD/ :
	{
		*(.comment)
		*(.debug*)
		*(.riscv.attributes)
	}
}