.intel_syntax noprefix

.global test_quad
test_quad:
    movss xmm0, [rcx]
    movss xmm1, [rdx]
    movss xmm2, [r8]
    call quadratic
    movss [rcx], xmm0
    movss [rdx], xmm1
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

    #Check if we hit a ray
    cmp edx, -1
    jne ray_hit

    ray_fallback:
    #Use ambient color as a fallback
    movss xmm0, [r11+48]
    movss xmm1, [r11+52]
    movss xmm2, [r11+56]
    jmp ray_end

    ray_hit_sphere:
    #Hit a sphere; if closer save the distance and material
    comiss xmm3, xmm6
    ja ray_hit_sphere_return #Not closer, ignore

    movss xmm6, xmm3
    mov edx, [rcx+16]

    jmp ray_hit_sphere_return
    ray_hit:
    mov rcx, [r11+16] #Contains base of materials array
    imul edx, 12 #Contains material offset
    add rcx, rdx #Contains the material

    movss xmm0, [rcx+0]
    movss xmm1, [rcx+4]
    movss xmm2, [rcx+8]
    ray_end:
    pop rsp

    ret 24 #Cleans up stack passed parameters
.LC0:
    .long   1148846080 #1000
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
    jb line_sphere_fail

    #We've detected a valid intersection
    movss xmm3, xmm0 #Leave distance in xmm3

    #Time to get the intersection point
    #We need to recalculate the direction vector
    #This should be improved, but it's fine for now

    #Begin X
    movss xmm5, [rsp + 16]
    movss xmm0, [rsp + 28]
    subss xmm4, xmm0 #xmm4 contains the x component of the normalize direction vec
    mulss xmm4, xmm3 #xmm4 contains the x component of the offset vec
    addss xmm0, xmm4
    #End X

    #Begin Y
    movss xmm5, [rsp + 20]
    movss xmm1, [rsp + 32]
    subss xmm4, xmm1 #xmm4 contains the y component of the normalize direction vec
    mulss xmm4, xmm3 #xmm4 contains the y component of the offset vec
    addss xmm1, xmm4
    #End Y

    #Begin Z
    movss xmm5, [rsp + 24]
    movss xmm2, [rsp + 36]
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
