ENTRY(_start);
OUTPUT_FORMAT(elf32-i386);
OUTPUT_ARCH(i386);
SECTIONS
{
	. = 0x0000;

	.text : AT(0x0000)
	{
		*(.text);
	}

	/DISCARD/ :
	{
		*(*);
	}
}
