.intel_syntax noprefix

.LC9: #Main variables
    .long 4 #Number of rays per bounce
.LC10:
    .long 4 #Recursion depth
.LC11:
    .long 16 #Number of samples

.global test_quad
test_quad:
    movss xmm0, [rcx]
    movss xmm1, [rdx]
    movss xmm2, [r8]
    call quadratic
    movss [rcx], xmm0
    movss [rdx], xmm1
    ret

.global asm_rand
asm_rand:
    sub rsp, 24
    movss [rsp+ 0], xmm0
    movss [rsp+ 4], xmm1
    movss [rsp+ 8], xmm2
    movss [rsp+12], xmm3
    movss [rsp+16], xmm4
    movss [rsp+20], xmm5

    sub rsp, 8
    call rand
    add rsp, 8
    
    movss [rsp+ 0], xmm0
    movss [rsp+ 4], xmm1
    movss [rsp+ 8], xmm2
    movss [rsp+12], xmm3
    movss [rsp+16], xmm4
    movss [rsp+20], xmm5
    add rsp, 24
    ret

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

        push rdx
        mov edx, .LC11 [rip] #Samples
        mov r13, rdx #r13 contains the number of samples
        pop rdx

        pxor xmm10, xmm10
        pxor xmm11, xmm11
        pxor xmm12, xmm12

        generate_ray_loop:
            push r13
            push rsi
            push rdx
            push r10
            push r9

            sub rsp, 24
            movss [rsp+0], xmm10
            movss [rsp+4], xmm11
            movss [rsp+8], xmm12

            #load the camera position and angle
            #r12 will contain the pointer to the camera struct
            mov r12, [r11+40]
            sub rsp, 24 #Pushing onto stack
            movss xmm0, [r12+0]
            movss xmm1, [r12+4]
            movss xmm2, [r12+8]
a:
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

            push rdx
            mov edx, .LC10 [rip] #Max bounces
            mov r8, rdx
            pop rdx

            call ray

            movss xmm10, [rsp+0]
            movss xmm11, [rsp+4]
            movss xmm12, [rsp+8]
            add rsp, 24

            addss xmm10, xmm0
            addss xmm11, xmm1
            addss xmm12, xmm2


            pop r9
            pop r10
            pop rdx
            pop rsi
            pop r13

            dec r13
            cmp r13, 0
            jg generate_ray_loop

        pop r9
        pop rdx
        pop r10
        pop rsi
        pop rax
        pop r15

        push rdx
        mov edx, .LC11 [rip]
        cvtsi2ss xmm13, edx #Division part of average
        pop rdx

        divss xmm10, xmm13 #Final from all ray R
        divss xmm11, xmm13 #Final from all ray G
        divss xmm12, xmm13 #Final from all ray B

        movss [r15+0], xmm10
        movss [r15+4], xmm11
        movss [r15+8], xmm12
        add r15, 12

        inc eax

    dec r9
    jnz loop_2

    dec r10
    jnz loop_1

    #restore
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

    divss xmm5, xmm6 #xmm5 now contains 1/aspect ratio
    mulss xmm4, xmm5 #xmm4 now contains y coordinate adjusted for aspect ratio
    
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

    cvtsd2ss xmm0, xmm0 #Convert back to float
    cvtsd2ss xmm1, xmm1 #Convert back to float
    cvtsd2ss xmm2, xmm2 #Convert back to float

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
    .long 1056964608 #0.5
#Inputs: The ray start position and direction, on the stack
#        Remaining recursion depth in r8
#        Scene pointer in r11
#Outputs: The r, g, and b values in xmm0, xmm1, and xmm2
#Writes: Like everything
ray:
    push rsp
    #Stack contains:
    # rsp +  0 -> rsp +  8: old rsp
    # rsp +  8 -> rsp + 16: return address
    # rsp + 16 -> rsp + 28: position data
    # rsp + 28 -> rsp + 40: rotation data

    movss xmm6, DWORD PTR .LC0[rip] #Will contain the closest object

    mov rbp, rsp
    
    mov rcx, [r11+ 0]
    mov r9, rcx
    mov edx, [r11+32]
    imul edx, 20
    add r9, rdx
    mov edx, -1 #Contains material hit ID
    sub rsp, 24
    ray_sphere_loop:
        #Load information for intersection call into stack
        sub rsp, 40

        #Line start pos
        movss xmm0, [rbp+16]
        movss [rsp+0], xmm0
        movss xmm0, [rbp+20]
        movss [rsp+4], xmm0
        movss xmm0, [rbp+24]
        movss [rsp+8], xmm0

        #Line direction
        movss xmm0, [rbp+28]
        movss [rsp+12], xmm0
        movss xmm0, [rbp+32]
        movss [rsp+16], xmm0
        movss xmm0, [rbp+36]
        movss [rsp+20], xmm0

        #Sphere pos
        movss xmm0, [rcx+0]
        movss [rsp+24], xmm0
        movss xmm0, [rcx+4]
        movss [rsp+28], xmm0
        movss xmm0, [rcx+8]
        movss [rsp+32], xmm0

        #Sphere radius
        movss xmm0, [rcx+12]
        movss [rsp+36], xmm0

        call line_sphere

        cmp eax, 0
        je ray_hit_sphere
        ray_hit_sphere_return:

        add rcx, 20
        cmp rcx, r9
        jb ray_sphere_loop
        jmp ray_end_sphere_loop

        ray_hit_sphere:
            #Hit a sphere; if closer save the distance and material
            comiss xmm3, xmm6
            ja ray_hit_sphere_return #Not closer, ignore

            movss xmm6, xmm3 #Save distance
            mov edx, [rcx+16] #Material

            movss [rsp+ 0], xmm0 #x-pos
            movss [rsp+ 4], xmm1 #y-pos
            movss [rsp+ 8], xmm2 #z-pos

            #To get the normal position, we will subtract the sphere center from the position
            #then normalize the position

            movss xmm4, [rcx+0]
            subss xmm0, xmm4 #x-offset from center
            movss xmm4, [rcx+4]
            subss xmm1, xmm4 #y-offset from center
            movss xmm4, [rcx+8]
            subss xmm2, xmm4 #z-offset from center

            call normalize

            movss [rsp+12], xmm0 #x-normal
            movss [rsp+16], xmm1 #y-normal
            movss [rsp+20], xmm2 #z-normal

            jmp ray_hit_sphere_return

    ray_end_sphere_loop:
    #Check if we hit a ray
    cmp edx, -1
    jne ray_hit

    ray_fallback:
    #Use ambient color as a fallback
    movss xmm0, [r11+48]
    movss xmm1, [r11+52]
    movss xmm2, [r11+56]

    jmp ray_end

    ray_hit:
        mov rcx, [r11+16] #Contains base of materials array
        imul edx, 20 #Contains material offset
        add rcx, rdx #Contains the material

        cmp r8, 0
        je ray_recursion_end #Reach recursion depth; stop and return

        pxor xmm13, xmm13 #R accumulator
        pxor xmm14, xmm14 #G accumulator
        pxor xmm15, xmm15 #B accumulator

        mov edx, .LC9 [rip] #Iterations left
        mov r12, rdx
        ray_hit_scatter_loop:
            movss xmm0, [rsp+0] #Ray hit pos x
            movss xmm1, [rsp+4] #Ray hit pos y
            movss xmm2, [rsp+8] #Ray hit pos z

            movss xmm3, [rbp+16] #Ray start pos x
            movss xmm4, [rbp+20] #Ray start pos y
            movss xmm5, [rbp+24] #Ray start pos z

            subss xmm0, xmm3 #Unnormalized ray direction x
            subss xmm1, xmm4 #Unnormalized ray direction y
            subss xmm2, xmm5 #Unnormalized ray direction z

            call normalize

            movss xmm3, [rsp+12] #Hit normal x
            movss xmm4, [rsp+16] #Hit normal y
            movss xmm5, [rsp+20] #Hit normal z

            call reflect #Next ray direction for purely specular in xmm0 - xmm2

            movss xmm3, [rsp+12] #Hit normal x
            movss xmm4, [rsp+16] #Hit normal y
            movss xmm5, [rsp+20] #Hit normal z

            call random_ray #Next ray direction for purely diffuse in xmm3 - xmm5

            movss xmm6, [rcx+16] #Roughness
            call slerp #Places final ray in xmm0 - xmm2

            movss xmm3, [rsp+0] #Next ray start pos x
            movss xmm4, [rsp+4] #Next ray start pos y
            movss xmm5, [rsp+8] #Next ray start pos z

            push r12
            push r8
            push rcx
            push rbp
            sub rsp, 16
            movss [rsp+0], xmm13
            movss [rsp+4], xmm14
            movss [rsp+8], xmm15

            dec r8

            sub rsp, 40 #Pushing onto stack
            movss [rsp+12], xmm0
            movss [rsp+16], xmm1
            movss [rsp+20], xmm2 #Ray direction

            movss [rsp+ 0], xmm3
            movss [rsp+ 4], xmm4
            movss [rsp+ 8], xmm5 #Start position

            call ray
            add rsp, 16

            movss xmm13, [rsp+0]
            movss xmm14, [rsp+4]
            movss xmm15, [rsp+8]
            add rsp, 16

            addss xmm13, xmm0
            addss xmm14, xmm1
            addss xmm15, xmm2 #Store for running average

            pop rbp
            pop rcx
            pop r8
            pop r12

            dec r12
            cmp r12, 0
            jg ray_hit_scatter_loop

        #END LOOP

        mov edx, .LC9 [rip]
        cvtsi2ss xmm12, edx #Division part of average
        divss xmm13, xmm12 #Final from all ray R
        divss xmm14, xmm12 #Final from all ray G
        divss xmm15, xmm12 #Final from all ray B

        movss xmm0, xmm13
        movss xmm1, xmm14
        movss xmm2, xmm15

        // jmp ray_end

        movss xmm3, [rcx+0] #Copy material color
        movss xmm4, [rcx+4]
        movss xmm5, [rcx+8]
        movss xmm6, [rcx+12] #Emission

        mulss xmm0, xmm3
        mulss xmm1, xmm4
        mulss xmm2, xmm5 #Multiply colors

        mulss xmm3, xmm6
        mulss xmm4, xmm6
        mulss xmm5, xmm6 #Calculate emission strength
        
        addss xmm0, xmm3 #Add emmision
        addss xmm1, xmm4 #Add emmision
        addss xmm2, xmm5 #Add emmision

        jmp ray_end
    ray_recursion_end:
        movss xmm0, [r11+48]
        movss xmm1, [r11+52]
        movss xmm2, [r11+56]

        movss xmm3, [rcx+0] #Copy material color
        movss xmm4, [rcx+4]
        movss xmm5, [rcx+8]
        movss xmm6, [rcx+12] #Emission
        mulss xmm3, xmm6
        mulss xmm4, xmm6
        mulss xmm5, xmm6 #Calculate emission strength
        
        addss xmm0, xmm3 #Add emmision
        addss xmm1, xmm4 #Add emmision
        addss xmm2, xmm5 #Add emmision
    ray_end:
    add rsp, 24
    pop rsp
    ret 24 #Cleans up stack passed parameters
.LC0:
    .long 1148846080 #1000
.LC1:
    .long 1065353216 #1

#Finds the roots r and s of the equation ax^2 + bx + c = 0
#Inputs: a, b, and c in xmm0, xmm1, and xmm2
#Outputs: r and s in xmm0 and xmm1. No guaruntee to order
#         eax of 0 if the operation was successful, -1 otherwise
#Writes: xmm3, xmm4
.global quadratic
quadratic:
    #Find b^2
    movss xmm3, xmm1
    mulss xmm3, xmm3 #xmm3 now contains b^2

    #Find 4ac
    movss xmm4, DWORD PTR .LC5[rip] #xmm4 now contains 4
    mulss xmm4, xmm0
    mulss xmm4, xmm2 #xmm4 now contains 4ac
    
    subss xmm3, xmm4 #determinant is in xmm3
    pxor xmm4, xmm4 #load 0
    comiss xmm3, xmm4
    jb quadratic_fail
    #all good

    sqrtss xmm3, xmm3 #xmm3 now has sqrt(b^2-4ac)

    movss xmm4, xmm0
    addss xmm4, xmm4 #xmm4 now has 2a

    movss xmm2, DWORD PTR .LC6[rip] #xmm2 now has -1

    movss xmm0, xmm1
    mulss xmm0, xmm2 #xmm0 now has -b
    addss xmm0, xmm3 #+ path
    divss xmm0, xmm4 #xmm0 has the first root

    mulss xmm1, xmm2 #xmm1 now has -b
    subss xmm1, xmm3 #- path
    divss xmm1, xmm4 #xmm1 has the second root

    quadratic_success:
    xor eax, eax #mark success
    ret

    quadratic_fail:
    mov eax, -1
    ret
.LC5:
    .long 1082130432 #4
.LC6:
    .long -1082130432 #-1

#Finds the two intersections of a line and a sphere
#Inputs (on stack): (x, y, z) of line start pos
#                   (x, y, z) of line direction vector
#                   (x, y, z) of circle center
#                   radius of circle
#Outputs: 0 if success, -1 if not in eax
#         x, y, z of *closer* intersection point
#         in xmm0, xmm1, and xmm2, if found
#         The distance will be left in xmm3
#Writes: xmm0 - xmm5, eax
line_sphere:
    push rsp
    #Stack contains:
    # rsp +  0 -> rsp +  8: old rsp
    # rsp +  8 -> rsp + 16: return address
    # rsp + 16 -> rsp + 28: line position data
    # rsp + 28 -> rsp + 40: line direction data
    # rsp + 40 -> rsp + 52: circle position data
    # rsp + 52 -> rsp + 56: circle radius

    #https://stackoverflow.com/questions/5883169/intersection-between-a-line-and-a-sphere
line_sphere_modify_input:    
    #This fomrula wants the line as two endpoints
    #First we modify the stack values to fit this specification
    #Calculate x1
    movss xmm0, [rsp + 16]
    movss xmm1, [rsp + 28]
    addss xmm0, xmm1
    movss [rsp + 28], xmm0

    #Calculate y1
    movss xmm0, [rsp + 20]
    movss xmm1, [rsp + 32]
    addss xmm0, xmm1
    movss [rsp + 32], xmm0

    #Calculate z1
    movss xmm0, [rsp + 24]
    movss xmm1, [rsp + 36]
    addss xmm0, xmm1
    movss [rsp + 36], xmm0

line_sphere_contruct_quadratic:
    #Second, we construct A, B, and C of the eventually quadratic
    #A will be in xmm0, B in xmm1, etc. This matches the calling 
    #convention of the quadratic finder, except the person who wrote
    #decided C was the squared term and A was the constant term

    #Begin A
    #(x0-xc)^2
    movss xmm3, [rsp+16]
    movss xmm4, [rsp+40]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    movss xmm2, xmm3

    #(y0-yc)^2
    movss xmm3, [rsp+20]
    movss xmm4, [rsp+44]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm2, xmm3

    #(z0-zc)^2
    movss xmm3, [rsp+24]
    movss xmm4, [rsp+48]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm2, xmm3

    #-R^2
    movss xmm5, [rsp+52]
    mulss xmm5, xmm5
    subss xmm2, xmm5
    #A complete

    #Begin C
    #(x0-x1)^2
    movss xmm3, [rsp+16]
    movss xmm4, [rsp+28]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    movss xmm0, xmm3

    #(y0-y1)^2
    movss xmm3, [rsp+20]
    movss xmm4, [rsp+32]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm0, xmm3

    #(z0-z1)^2
    movss xmm3, [rsp+24]
    movss xmm4, [rsp+36]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm0, xmm3
    #C done

    #Begin B
    #(x1-xc)^2
    movss xmm3, [rsp+28]
    movss xmm4, [rsp+40]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    movss xmm1, xmm3

    #(y1-yc)^2
    movss xmm3, [rsp+32]
    movss xmm4, [rsp+44]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm1, xmm3

    #(z1-yc)^2
    movss xmm3, [rsp+36]
    movss xmm4, [rsp+48]
    subss xmm3, xmm4
    mulss xmm3, xmm3
    addss xmm1, xmm3

    #-A -C
    subss xmm1, xmm2
    subss xmm1, xmm0

    #-R^2
    #reuse value from previous time
    subss xmm1, xmm5

line_sphere_finish:

    call quadratic
    cmp eax, 0
    jne line_sphere_fail #No solution
    
    comiss xmm0, xmm1 #Find smaller t-value. Smaller value will be closer
    jbe line_sphere_skip
    movss xmm0, xmm1
    line_sphere_skip:

    #If the value is behind, we can't see it
    #This does ignore the case where the smaller value is < 0 and the larger
    #value is > 0, but in that case we'd be inside the sphere anyway
    pxor xmm1, xmm1
    comiss xmm0, xmm1
    jbe line_sphere_fail

    #We've detected a valid intersection
    movss xmm3, xmm0 #Leave distance in xmm3

    #Time to get the intersection point
    #We need to recalculate the direction vector
    #This should be improved, but it's fine for now

    #Begin X
    movss xmm0, [rsp + 16]
    movss xmm4, [rsp + 28]
    subss xmm4, xmm0 #xmm4 contains the x component of the normalize direction vec
    mulss xmm4, xmm3 #xmm4 contains the x component of the offset vec
    addss xmm0, xmm4
    #End X

    #Begin Y
    movss xmm1, [rsp + 20]
    movss xmm4, [rsp + 32]
    subss xmm4, xmm1 #xmm4 contains the y component of the normalize direction vec
    mulss xmm4, xmm3 #xmm4 contains the y component of the offset vec
    addss xmm1, xmm4
    #End Y

    #Begin Z
    movss xmm2, [rsp + 24]
    movss xmm4, [rsp + 36]
    subss xmm4, xmm2 #xmm4 contains the z component of the normalize direction vec
    mulss xmm4, xmm3 #xmm4 contains the z component of the offset vec
    addss xmm2, xmm4
    #End Z

    xor eax, eax
    jmp line_sphere_return
    line_sphere_fail:
    mov eax, -1
    line_sphere_return:
    pop rsp
    ret 40


#Normalizes a vecotr in xmm0, xmm1, and xmm2 to length 1
#Inputs: The vector in xmm0 - xmm2
#Outputs: The normalized vector in xmm0 - xmm2
#Writes: xmm0 - xmm2
normalize:
    sub rsp, 8
    movss [rsp+0], xmm3 #Scratch space
    movss [rsp+4], xmm4

    movss xmm3, xmm0
    mulss xmm3, xmm3 #x^2
    movss xmm4, xmm1
    mulss xmm4, xmm4 #y^2
    addss xmm3, xmm4
    movss xmm4, xmm2
    mulss xmm4, xmm4 #z^2
    addss xmm3, xmm4 #Length squared in xmm3
    sqrtss xmm3, xmm3 #Length in xmm3

    divss xmm0, xmm3
    divss xmm1, xmm3
    divss xmm2, xmm3

    movss xmm3, [rsp+0]
    movss xmm4, [rsp+4]
    add rsp, 8
    ret
#Calculates the dot product between two vectors
#Inputs: The vectors in xmm0 - xmm2 and xmm3 - xmm5
#Outputs: The dot product in xmm0
#Writes: xmm0 - xmm2
dot:
    mulss xmm0, xmm3 #Component wise
    mulss xmm1, xmm4
    mulss xmm2, xmm5

    addss xmm0, xmm1 #Add components
    addss xmm0, xmm2 #Add components

    ret

#Multiples the components of a vector with a scalar
#Inputs: The vector in xmm0 - xmm2 and the scalar in xmm3
#Outputs: The vector in xmm0 - xmm2
#Writes: xmm0 - xmm2
scalar_mul:
    mulss xmm0, xmm3
    mulss xmm1, xmm3
    mulss xmm2, xmm3
    ret

#This calculates the reflection vector across a surface
#Inputs: The input direction vector in xmm0 - xmm2
#        The normal vector of the surface in xmm3 - xmm5
#Outputs: The reflected vector in xmm0 - xmm2
#Writes: xmm0 - xmm5
reflect:
    #https://math.stackexchange.com/questions/13261/how-to-get-a-reflection-vector
    sub rsp, 12
    movss [rsp+0], xmm0
    movss [rsp+4], xmm1
    movss [rsp+8], xmm2

    call dot #Dot product of d and n is in xmm0
    addss xmm0, xmm0 #Multiply by two

    mulss xmm3, xmm0
    mulss xmm4, xmm0
    mulss xmm5, xmm0 #Calculate 2(d*n)n

    movss xmm0, [rsp+0]
    movss xmm1, [rsp+4]
    movss xmm2, [rsp+8] #Get d back
    add rsp, 12

    subss xmm0, xmm3
    subss xmm1, xmm4
    subss xmm2, xmm5 #Component-wise subtract

    ret
#Generates a random float [-1, 1]
#Outputs: The random float in xmm0
#Writes: xmm0
// rand_float:
//     push rcx
//     push rax
//     sub rsp, 4
//     movss [rsp], xmm1

//     call asm_rand #Random int now in eax
//     mov rcx, 16383
//     and rax, rcx #rax now has a number from [0, 16383]
//     cvtsi2ss xmm0, rax #xmm0 now has a number from [0, 16383]
//     movss xmm1, DWORD PTR .LC3[rip] #xmm1 has 16383.5
//     divss xmm0, xmm1 #xmm0 now has a number from [0, 2]
//     movss xmm1, DWORD PTR .LC6[rip] #xmm1 has -1
//     subss xmm0, xmm1 #xmm0 now has a number from [-1, 1]

//     movss xmm1, [rsp]
//     add rsp, 4
//     pop rax
//     pop rcx
//     ret
// .LC3:
//     .long 1182793216 #16383.5
#Creates a random ray from a surface normal
#Inputs: The surface normal in xmm3 - xmm5
#Outputs: The random ray in xmm3 - xmm5
#Writes: xmm3 - xmm5
random_ray:
    sub rsp, 36
    movss [rsp+ 0], xmm0
    movss [rsp+ 4], xmm1
    movss [rsp+ 8], xmm2
    movss [rsp+12], xmm6
    movss [rsp+16], xmm7
    movss [rsp+20], xmm8
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11

    #We will generate a random point on a sphere
    #Then we will use the dot product to see if it is in the hemisphere around the normal
    #If not, we will invert it

    #https://math.stackexchange.com/questions/1585975/how-to-generate-random-points-on-a-sphere
    call rand_float
    movss xmm6, xmm0 #xmm6 has future z value

    call rand_float
    movss xmm1, DWORD PTR .LC7[rip]
    mulss xmm0, xmm1 #xmm0 now contains the theta value
    cvtss2sd xmm0, xmm0
    movsd xmm7, xmm0 #xmm7 now contains the theta value

    sub rsp, 20

    call sin #xmm0 now contains sin theta
    movsd xmm8, xmm0 #xmm8 now contains sin theta as a double
    movsd xmm0, xmm7
    call cos #xmm0 now contains cos theta as a double

    add rsp, 20

    cvtsd2ss xmm8, xmm8 #xmm8 now contains sin theta
    cvtsd2ss xmm0, xmm0 #xmm0 now contains cos theta
    movss xmm1, xmm8
    movss xmm2, xmm7

    call normalize #normalize direction vector

    movss xmm3, xmm0 #move the normalized direction vector
    movss xmm4, xmm1
    movss xmm5, xmm2

    movss xmm0, [rsp+24]
    movss xmm1, [rsp+28]
    movss xmm2, [rsp+32] #load the saved normal vector

    call dot #dot product in xmm0, normalized direction vector remains in xmm3 - xmm5

    movss xmm1, DWORD PTR .LC8[rip] #load 1
    movss xmm2, DWORD PTR .LC6[rip] #load -1
    pxor xmm6, xmm6 #load 0

    comiss xmm0, xmm6
    // fcmovb xmm1, xmm2 #move if less than 0
    // #A condition move is used because by definition this should be 50-50 random, so a branch
    // #would be slow
    // Error: operand size mismatch for `fcmovb'
    // TODO: FIXME - i think CMOV would have a decent speed advantage
    ja random_ray_cond
    movss xmm1, xmm2
    random_ray_cond:

    mulss xmm3, xmm1
    mulss xmm4, xmm1
    mulss xmm5, xmm1

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    movss xmm0, [rsp+ 0]
    movss xmm1, [rsp+ 4]
    movss xmm2, [rsp+ 8]
    movss xmm6, [rsp+12]
    movss xmm7, [rsp+16]
    movss xmm8, [rsp+20]
    add rsp, 36
    ret
.LC7:
    .long 1078530011 #pi
.LC8:
    .long 1065353216 #1

#Spherically lerps between two values
#Assumes the inputs are normalized vectors
#This uses a naive approach that I believe is still accurate for normalized vectors
#It takes a lerp of the two vectors, then normalizes the result
#Inputs: The first vector in xmm0 - xmm2
#        The second vector in xmm3 - xmm5
#        The t value in xmm6
#Outputs: The slerped vector in xmm0 - xmm2
#Writes: xmm0 - xmm5
slerp:
    call lerp
    call normalize
    ret

#Linearly lerps between two values
#Inputs: The first vector in xmm0 - xmm2
#        The second vector in xmm3 - xmm5
#        The t value in xmm6
#Outputs: The lerped vector in xmm0 - xmm2
#Writes: xmm0 - xmm5
lerp:
    sub rsp, 4
    movss [rsp], xmm7

    mulss xmm3, xmm6
    mulss xmm4, xmm6
    mulss xmm5, xmm6 #Multiply by t

    #Get 1-xmm6 into xmm7
    movss xmm7, DWORD PTR .LC8[rip]
    subss xmm7, xmm6

    mulss xmm0, xmm7
    mulss xmm1, xmm7
    mulss xmm2, xmm7 #Multiply by 1-t

    addss xmm0, xmm3
    addss xmm1, xmm4
    addss xmm2, xmm5 #Add two components together

    movss xmm7, [rsp]
    add rsp, 4

    ret
