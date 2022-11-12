.intel_syntax noprefix

.global generate
#void generate(color *array, unsigned int width, unsigned int height);
#*array is in rcx, width is in edx, and height is in r8
generate:
    push r9
    mov r9, r8
    mov eax, edx
    movss xmm0, DWORD PTR .LC0[rip]

    #r8 is height
    #r9 is y-axis counter
    #eax is width
    #edx is the x-axis counter

    cvtsi2ss xmm5, eax
    mov rbx, r8
    cvtsi2ss xmm4, ebx
    #xmm5 is the height as a float
    #xmm4 is the width as a float

loop_1:
    mov edx, eax
loop_2:
    #loop body
    #red
    cvtsi2ss xmm0, edx
    divss xmm0, xmm5
    movss [rcx], xmm0
    add rcx, 4

    #green
    cvtsi2ss xmm3, edx
    mov rbx, r9
    cvtsi2ss xmm2, ebx
    mulss xmm3, xmm3
    mulss xmm2, xmm2
    addss xmm2, xmm3
    sqrtss xmm2, xmm2
    movss xmm0, DWORD PTR .LC1[rip]
    addss xmm2, xmm0
    divss xmm0, xmm2
    movss [rcx], xmm0
    add rcx, 4

    #blue
    mov rbx, r9
    cvtsi2ss xmm0, ebx
    divss xmm0, xmm4
    movss [rcx], xmm0
    add rcx, 4

    dec edx
    jnz loop_2

    dec r9
    jnz loop_1

    pop r9

    ret
.LC0:
    .long   1065353216
.LC1:
    .long   1112014848