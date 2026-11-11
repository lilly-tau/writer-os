	.code16
	.text
	.globl _start

	# From the first stage bootloader we expect:
	# DL -> BOOT DRIVE
	# DS:SI -> Partition table.
	# 0:600h -> MBR
	# DH -> flags	0=A20-ENABLED
_start:
	push %ds
	pop partition.segment
	mov %si, partition.address
	mov %dl, drive
	mov %dh, flags

	# Set DS to the correct code segment
	push %cs
	pop %ds

	# Print the BOOT2 message.
	mov $welcome, %si
	mov $welcome.count, %cx
	call print

	# Enable A20 line
	testb $0x01, flags	# Check if A20 is enabled
	jnz 0f			# We might need a 16 bit jump
	call enable_a20
0:

	# Copy the GDT into 0:0x600, 
	mov gdt, %si
	xor %ax, %ax
	mov %ax, %es
	mov $0x600, %di
	mov $gdt_full_length, %cx
	rep movsb

	# Load the gdt
	lgdt %es:0x600+gdtr-gdt

	# So we should now read the file "BOOTCFG" into memory.
	push partition.segment
	pop %es
	mov partition.address, %bx
0:
	hlt
	jmp 0b

enable_a20:
	cli

	# Use keyboard 8042 chip.
	call a20.8042wait
	mov $0xAD, %al			# Disable keyboard
	out %al, $0x64

	call a20.8042wait
	mov $0xD0, %al			# Read controller output port
	out %al, $0x64

	call a20.8042wait2
	in $0x60, %al			# Save response byte
	push %ax

	call a20.8042wait
	mov $0xD1, %al			# Write next byte to controller output
					# port
	out %al, $0x64

	call a20.8042wait
	pop %ax
	or $0x02, %al			# Enable A20
	out %al, $0x60

	call a20.8042wait
	mov $0xAE, %al			# Enable keybaord
	out %al, $0x64

	call a20.8042wait

.ifdef FAST_A20
	# Fast A20
	in $0x92, %al
	test $0x02, %al
	jnz 0f
	or $0x02, %al
	out %al, $0x92
0:
.endif

.ifdef EE_A20
	in $0xEE, %al
.endif

	# Use the BIOS at the end, just in case
	mov $0x2403, %ax
	int $0x15
	jc 0f			# Not supported
	or %ah, %ah
	jnz 0f			# Not supported

	mov $0x2402, %ax
	int $0x15
	jc 1f			# Error
	or %ah, %ah
	jnz 1f			# Error
	or %al, %al
	jnz 0f			# Already enabled by my fine handywork :D
	# Activate A20
	mov $0x2401, %ax
	int $0x15
	jc 1f
	or %ah, %ah
	jz 0f
1:	# BIOS A20 <<ERROR>>
	mov a20err, %si
	mov a20err.count, %cx
	call print
	jmp 0f
2:
0:
	sti
	ret
a20.8042wait:
	in $0x64, %al
	test $0x02, %al
	jnz a20.8042wait
	ret
a20.8042wait2:
	in $0x64, %al
	test $0x01, %al
	jnz a20.8042wait2
	ret

print:	# (si=string, cx=length)
	mov $0x0E, %ah
0:
	lodsb
	int $0x10
	loop 0b
	ret

drive:			.byte 0x00
flags:			.byte 0x00
partition.segment:	.word 0x00
partition.address:	.word 0x00

.macro gdt_entry limit, base, access, flags
	.word \limit & 0xFFFF
	.word \base & 0xFFFF
	.byte (\base >> 0x10) & 0xFF
	.byte \access
	.byte ((\limit >> 0x10) & 0xF) | ((\flags << 0x04) & 0xFF)
	.byte (\base >> 0x18) & 0xFF
.endm

gdt:
	gdt_entry 0x00, 0x00, 0x00, 0x00
	gdt_entry 0xFFFFF, 0x00, 0x9A, 0x0C
	gdt_entry 0xFFFFF, 0x00, 0x92, 0x0C
	gdt_entry 0xFFFFF, 0x00, 0xFA, 0x0C
	gdt_entry 0xFFFFF, 0x00, 0xF2, 0x0C
gdtr:
	.word gdtr-gdt-1
	.long 0x600
gdt_full_length:

.if gdt_full_length-gdt > 0x1BE
	.error "gdt larger than allocated space at 0x600"
.endif

.macro strdef name, data
\name\():
	.ascii "\data"
.set \name\().count, .-\name
.endm

strdef welcome, "BOOT2\r\n"
strdef a20err, "Could not enable A20 (via BIOS)\r\n"
