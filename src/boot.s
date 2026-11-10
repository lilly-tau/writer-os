###############################################################################
#	BOOTLOADER
###############################################################################
	.code16
	.text
	.globl _start
_start:
	ljmp $0x00, $reset	# Set CS
reset:
	# Init all of the segment registers and stack
	push %cs
	push %cs
	push %cs
	pop %es
	pop %ds
	pop %ss
	mov $0x7C00, %sp
	mov %dl, drive		# Store the drive, we will need to give this to
				# the second stage bootloader.
	mov %ds, %ax
	mov %ax, mbr.segment	# Partition values
	mov %si, mbr.address	# Partition values

	# Set the video mode
	mov $0x02, %ax
	int $0x10

	# Print the debug message
	mov $welcome, %si
	mov $0x0E, %ah
0:
	lodsb
	or %al, %al
	jz 0f
	int $0x10
	jmp 0b
0:

	# We need to get the drive geometry [or waste HOURS of my time holy]
	mov $0x08, %ah
	mov drive, %dl
	xor %di, %di
	int $0x13
	mov %dh, heads
	mov %cx, %dx
	mov %cx, %ax

	# Cylinder geometry is (dh & 0xC << 2) | dl
	xchg %dh, %dl
	mov $0x06, %cl
	shr %cl, %dh
	mov %dx, cylinders

	# Sector geometry is ax & 0x3F
	and $0x3F, %al
	mov %al, sectors

	xor %ax, %ax
	inc %al
	push %ax
0:
	# Load the correct partition values for int 13h
	mov mbr.segment, %es
	mov mbr.address, %bx
	mov drive, %dl
	mov %es:0x01(%bx), %dh
	mov %es:0x02(%bx), %cx

	pop %ax
	push %ax
	call increment_chs

	# Finish the int 13h call.
	push %cs
	pop %es
	mov $0x8000, %bx
	mov $0x0201, %ax
	int $0x13
	jc error

	# Get the filesize
	mov $0x807C, %si
	mov $0x0B, %cx
	call read_oct

	mov $0x0A, %cl
	shr %cl, %ax
	inc %ax

	pop %bx
	add %ax, %bx
	push %bx

	cmpb $0x00, 0x8000
	je error

	# Check the filename (AND DONT MISSPELL IT YOU FUCKING TWAT)
	cmpw $0x4F42, 0x8000
	jne 0b
	cmpw $0x544F, 0x8002
	jne 0b

	pop %ax

	# Get the filesize
	mov $0x807C, %si
	mov $0x0B, %cx
	call read_oct

	mov $0x0A, %cl
	shr %cl, %ax
	inc %ax

	push %ax
	mov %sp, %di

	# Load file into memory
	mov mbr.segment, %es
	mov mbr.address, %bx
	mov drive, %dl
	mov %es:0x01(%bx), %dh
	mov %es:0x02(%bx), %cx

	inc %al			# from the start of the file
	call increment_chs	# AL should already be set

	# Finish the int 13h call.
	mov $0x1000, %ax
	mov %ax, %es
	xor %bx, %bx
	mov $0x0201, %ax
	int $0x13
	jc error

	ljmp $0x1000, $0x0000
error:
	mov $0x0E21, %ax
	int $0x10
halt:
	hlt
	jmp halt

# FIXME: AWFUL AWWWFULL FUNCTION, KILL IT WITH FIRE, KILLL ITTTT
increment_chs:	# (cx=cs, dh=h, al=amount)
	cmp sectors, %cl
	jb 0f
	and $0xC0, %cl
	inc %cl
	cmp heads, %dh
	jb 1f
	xor %dh, %dh
	inc %ch
	jnc 9f
	add $0x40, %cx
	jmp 9f
1:
	inc %dh
	jmp 9f
0:
	inc %cl
	jmp 9f
9:
	dec %al
	jnz increment_chs
	ret

read_oct:	# (si=offset, cx=length)
	push %cx
	push %dx
	push %bx
	mov %cx, %bx
	mov $0x03, %cl
	xor %dx, %dx
0:
	lodsb
	sub $0x30, %al
	shl %cl, %dx
	and $0xF, %al
	or %al, %dl
	dec %bx
	jnz 0b

	mov %dx, %ax
	pop %bx
	pop %dx
	pop %cx
	ret

prval:
	push %dx
	push %cx
	push %bx

	mov $0x04, %bx
	mov %bx, %cx
	mov %ax, %dx
0:
	mov %dh, %al
	shr %cl, %al
	cmp $0x0A, %al
	jb 1f
	add $0x07, %al
1:
	add $0x30, %al
	mov $0x0E, %ah
	int $0x10
	shl %cl, %dx
	dec %bx
	jnz 0b

	mov $0x0E0A, %ax
	int $0x10
	mov $0x0D, %al
	int $0x10

	pop %bx
	pop %cx
	pop %dx
	ret

# Partition table address
mbr.segment:	.word 0x00
mbr.address:	.word 0x00

# Drive geometry
drive:		.byte 0x00
cylinders:	.word 0x00
sectors:	.byte 0x00
heads:		.byte 0x00

welcome:	.ascii "BOOT1\r\n\0"
