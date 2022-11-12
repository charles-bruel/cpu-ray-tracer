.intel_syntax noprefix

.global generate
#void generate(color *array, unsigned int width, unsigned int height);
#*array is in rcx, width is in edx, height is in r8, and scene is in r9

#Special calling convention is as follows. Scene remains in r11
#Current recursion depth left is in r8
generate:
    #Conform to the standard and save registers all non-violatile registers
    #I do it once then don't have to worry about it
    #Called once so performance impact is minor
    push rbx
    push rbp
    push rdi
    push rsi
    push rsp
    push r12
    push r13
    push r14
    push r15
    // push xmm6
    // push xmm7
    // push xmm8
    // push xmm9
    // push xmm10
    // push xmm11
    // push xmm12
    // push xmm13
    // push xmm14
    // push xmm15

    mov r11, r9
    mov r15, rcx

    xor eax, eax

    mov rsi, r8
    mov r10, rsi
    mov r9, rdx

    #esi is height
    #r10 is y-axis counter
    #edx is width
    #r9 is the x-axis counter
loop_1:
    mov r9, rdx
loop_2:
    #loop body
    
    push r15
    push rax
    push rsi
    push r10
    push rdx
    push r9

    #load the camera position and angle
    #r12 will contain the pointer to the camera struct
    mov r12, [r11+40]
    sub rsp, 24 #Pushing onto stack
    movss xmm0, [r12+0]
    movss xmm1, [r12+4]
    movss xmm2, [r12+8]

    movss [rsp+0], xmm0
    movss [rsp+4], xmm1
    movss [rsp+8], xmm2
    #Position loaded

    movss xmm0, [r12+12]
    movss xmm1, [r12+16]
    movss xmm2, [r12+20]

    call adjust_ray_angle

    movss [rsp+12], xmm0
    movss [rsp+16], xmm1
    movss [rsp+20], xmm2
    #Rotation loaded

    call ray

    pop r9
    pop rdx
    pop r10
    pop rsi
    pop rax
    pop r15

    movss [r15+0], xmm0
    movss [r15+4], xmm1
    movss [r15+8], xmm2
    add r15, 12

    inc eax

    dec r9
    jnz loop_2

    dec r10
    jnz loop_1

    #restore
    // pop xmm15
    // pop xmm14
    // pop xmm13
    // pop xmm12
    // pop xmm11
    // pop xmm10
    // pop xmm9
    // pop xmm8
    // pop xmm7
    // pop xmm6
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsp
    pop rsi
    pop rdi
    pop rbp
    pop rbx

    ret
.LC0:
    .long   1065353216
.LC1:
    .long   1112014848

#This function is called between loading the ray and firing the ray
#It perspective projection for the camera
#Inputs: The ray direction in xmm0, xmm1, and xmm2
#        The screen height in esi
#        The x-axis counter in r10
#        The screen width in edx
#        The y-axis counter in r9
#        The scene pointer in r11
adjust_ray_angle:
    push r11

    #Clear some scratch space
    sub rsp, 48 #Pushing onto stack
    movss [rsp+ 0], xmm6
    movss [rsp+ 8], xmm7
    movss [rsp+16], xmm8
    movss [rsp+24], xmm9
    movss [rsp+32], xmm13
    movss [rsp+40], xmm14


    #First order of business is to convert counters and sizes into [-1, 1] range
    cvtsi2ss xmm4, edx
    mov rbx, r9
    cvtsi2ss xmm3, ebx
    
    divss xmm3, xmm4 #xmm3 contains [0, 1] x coordinate
    movss xmm6, xmm4


    cvtsi2ss xmm5, esi
    mov rbx, r10
    cvtsi2ss xmm4, ebx
    divss xmm4, xmm5 #xmm4 contains [0, 1] y coordinate

    subss xmm3, DWORD PTR .LC2[rip] #xmm3 contains [-0.5, 0.5] x coordinate
    subss xmm4, DWORD PTR .LC2[rip] #xmm4 contains [-0.5, 0.5] y coordinate

    divss xmm6, xmm5 #xmm5 now contains 1/aspect ratio
    mulss xmm4, xmm6 #xmm4 now contains y coordinate adjusted for aspect ratio
    
    mov rbx, [r11+40] #rbx now contains pointer to camera struct
    movss xmm5, [rbx+24] #xmm5 now contains camera FOV

    mulss xmm3, xmm5 #xmm3 now contains horizontal angle delta
    mulss xmm4, xmm5 #xmm4 now contains vertical angle delta

    movss xmm13, xmm3
    movss xmm14, xmm4
    cvtss2sd xmm13, xmm13 #xmm13 now contains horizontal angle delta as a double
    cvtss2sd xmm14, xmm14 #xmm14 now contains vertical angle delta as a double

    #https://math.stackexchange.com/questions/268064/move-a-point-up-and-down-along-a-sphere

    #Step 1: into spherical coordinates

    movss xmm7, xmm0 #Get xmm0 out of the way so we can invoke math
    movss xmm8, xmm1 #Get xmm1 out of the way so we can invoke math

    #r = 1
    #xmm2 = xmm2 / r
    cvtss2sd xmm0, xmm2 #to double
    sub rsp, 8
    call acos #xmm0 now contains theta as double
    movsd xmm6, xmm0 #xmm6 now contains theta as double

    movss xmm0, xmm8
    movss xmm1, xmm7
    cvtss2sd xmm0, xmm0 #xmm0 now contains y as double
    cvtss2sd xmm1, xmm1 #xmm1 now contains x as double
    call atan2 #xmm0 now contains rho as double
    
    addsd xmm0, xmm13 #xmm0 now contains final rho as a double
    addsd xmm6, xmm14 #xmm6 now contains final theta as a double
    movsd xmm7, xmm0 #xmm7 now contains final rho as a double

    #Step 2: back to cartesian
    #First calculate sin theta, cos theta, sin rho, cos rho
    #xmm0 still contains final rho as double
    call sin
    movsd xmm9, xmm0 #xmm9 now contains sin rho as a double
    movsd xmm0, xmm7
    call cos
    movsd xmm7, xmm0 #xmm7 now contains cos rho as a double
    movsd xmm0, xmm6
    call sin
    movsd xmm8, xmm0 #xmm8 now contains sin theta as a double
    movsd xmm0, xmm6
    call cos
    add rsp, 8
    movsd xmm2, xmm0 #xmm2 now contains cos theta as a double
                     #z-coordinate complete

    #Reassemble other cartesian coordinates
    movsd xmm0, xmm7
    mulsd xmm0, xmm8 #xmm0 now contains final x coordinate
    movsd xmm1, xmm9
    mulsd xmm1, xmm8 #xmm1 now contains final y coordinate

end2:
    cvtsd2ss xmm0, xmm0 #Convert back to float
    cvtsd2ss xmm1, xmm1 #Convert back to float
    cvtsd2ss xmm2, xmm2 #Convert back to float
end1:

    movss xmm6 , [rsp+ 0]
    movss xmm7 , [rsp+ 8]
    movss xmm8 , [rsp+16]
    movss xmm9 , [rsp+24]
    movss xmm13, [rsp+32] 
    movss xmm14, [rsp+40] 
    add rsp, 48 #Fix scratch space clearing

    pop r11

    ret
.LC2:
    .long 1056964608
.LC3:
    .long   1116471296
#This function somewhat violates the C calling conventions. It leaves the color result in xmm0-xmm2
#Inputs: The ray start position and direction, on the stack
#        Remaining recursion depth in r8
#        Scene pointer in r11
#Outputs: The r, g, and b values in xmm0, xmm1, and xmm2
ray:
    push rsp
    #Stack contains:
    # rsp +  0 -> rsp +  8: old rsp
    # rsp +  8 -> rsp + 16: return address
    # rsp + 16 -> rsp + 28: position data
    # rsp + 28 -> rsp + 40: rotation data

    movss xmm0, [rsp+28] #x component of position
    // movss xmm3, [rsp+16] #x component of direction
    // addss xmm0, xmm3

    movss xmm1, [rsp+32] #y component of position
    // movss xmm3, [rsp+20] #y component of direction
    // addss xmm1, xmm3

    movss xmm2, [rsp+36] #z component of position
    // movss xmm3, [rsp+24] #z component of direction
    // addss xmm2, xmm3


    pop rsp
    // movss xmm0, [r11+48]
    // movss xmm1, [r11+52]
    // movss xmm2, [r11+56]



    ret 24 #Cleans up stack passed parameters