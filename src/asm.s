.intel_syntax noprefix

.global generate
#void generate(color *array, unsigned int width, unsigned int height);
#*array is in rcx, width is in edx, height is in r8, and scene is in r9
generate:
    mov r11, r9

    push rbx
    push rsi

    xor eax, eax

    mov rsi, r8
    mov r10, rdx
    mov r9, rsi

    #esi is height
    #r10 is y-axis counter
    #edx is width
    #r9 is the x-axis counter
loop_1:
    mov r9, rsi
loop_2:
    #loop body
    #red
    movss xmm0, [r11+48]
    movss [rcx], xmm0
    add rcx, 4

    #green
    movss xmm0, [r11+52]
    movss [rcx], xmm0
    add rcx, 4

    #blue
    movss xmm0, [r11+56]
    movss [rcx], xmm0
    add rcx, 4

    inc eax

    dec r9
    jnz loop_2

    dec r10
    jnz loop_1

    pop rsi
    pop rbx

    ret
.LC0:
    .long   1065353216
.LC1:
    .long   1112014848