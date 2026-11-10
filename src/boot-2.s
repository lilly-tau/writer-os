	.code16
	.text
	.global _start
_start:
	mov $0x0E48, %ax
	int $0x10
	inc %al
	int $0x10
	mov $0x21, %al
	int $0x10
	jmp .
