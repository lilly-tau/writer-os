ENTRY(_start);
OUTPUT_FORMAT(elf32-i386);
OUTPUT_ARCH(i386);
SECTIONS
{
	. = 0x7C00;

	.text : AT(0x7C00)
	{
		*(.text);
		. = 0x1FE;
		SHORT(0xAA55);
	}

	/DISCARD/ :
	{
		*(*);
	}
}
