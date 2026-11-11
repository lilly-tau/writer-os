	.code16
	.text
	.globl poll_chs_geometry
	.globl offset_chs

poll_chs_geometry:	# (dl=drive) -> (cx = cylinders, dh = heads, 
			# dl = sectors)
	mov $0x08, %ah
	int $0x13
	push %dx
	mov %cx, %ax
	mov %cx, %dx

	# Get sectors
	and $0x3F, %ax
	push %ax

	# Get cylinders
	mov $0x06, %cl
	shr %cl, %dx

	pop %ax
	pop %dx
	mov %al, %dl
	ret

# FIXME: kinda awful
offset_chs:	# (al=amount, dh=H, cx=CS, [SP]=(heads<<8)|sectors) 
		# -> (dh=H, cx=CS)
	push %bp
	mov %sp, %bp
offset_chs.loop:
	mov %cl, %ah
	and $0x3F, %ah
	cmp 0x04(%bp), %ah
	jb 0f

	# Sector overflows
	and $0xC0, %cl
	inc %cl			# Index starts at 1
	cmp 0x05(%bp), %dh
	jb 1f

	# Heads overflow
	xor %dh, %dh
	inc %ch
	jnc offset_chs.continue
	add $0x40, %cl
	jmp offset_chs.continue
1:
	inc %dh
	jmp offset_chs.continue
0:
	inc %cl
offset_chs.continue:
	dec %al
	jnz offset_chs.loop
	ret $0x02
