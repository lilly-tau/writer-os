###############################################################################
#	MBR
###############################################################################
	.code16
	.text
	.globl _start
_start:
	ljmp $0x00, $first
first:
	push %cs
	push %cs
	push %cs
	pop %ds
	pop %es
	pop %ss
	mov $0x7000, %sp

	mov $0x7C00, %si
	mov $0x600, %di
	mov $0x200, %cx
	rep movsb
	ljmp $0x00, $(0x600+reset-0x7C00)
reset:
	mov $0x7BE, %si
	mov $0x04, %cx
0:
	cmpb $0x80, (%si)
	je 1f
	add $0x10, %si
	loop 0b
1:
	or %cl, %cl
	jz error

	push %si
	push %dx

	# Load the partition in %si
	mov 0x01(%si), %dh
	mov 0x02(%si), %cx
	mov $0x7C00, %bx
	mov $0x0201, %ax
	int $0x13
	jc error

	pop %dx
	pop %si
	ljmp $0x00, $0x7C00
error:
	mov $0x0E21, %ax
	int $0x10
0:
	hlt
	jmp 0b
