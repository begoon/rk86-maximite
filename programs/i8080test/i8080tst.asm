; Comestically modified to be compiled via asm8080.
; - $?? hexadecimals are changed to 0??h
; - added \r and \n the messages
; - .ds, .dw changed to ds/dw
;
; -- Alexander Demin / 08.10.2012
;
;************************************************************
;                8080/8085 CPU TEST/DIAGNOSTIC
;************************************************************
;
;note: (1) program assumes "call", "lxi sp" instructions work;
;
;      (2) instructions not tested are "hlt","di","ei",
;          and "rst 0" thru "rst 7"
;
;
;
;test jump instructions and flags
;
hexb:   equ    0f815h
puts:   equ    0f818h

cpu:    lxi     sp,stack ;set the stack pointer
        ani     0       ;initialize a reg. and clear all flags
        jz      j010    ;test "jz"
        call    cpuer
j010:   jnc     j020    ;test "jnc"
        call    cpuer
j020:   jpe     j030    ;test "jpe"
        call    cpuer
j030:   jp      j040    ;test "jp"
        call    cpuer
j040:   jnz     j050    ;test "jnz"
        jc      j050    ;test "jc"
        jpo     j050    ;test "jpo"
        jm      j050    ;test "jm"
        jmp     j060    ;test "jmp" (it's a little late,but what the hell;
j050:   call    cpuer
j060:   adi     6       ;a=6,c=0,p=1,s=0,z=0
        jnz     j070    ;test "jnz"
        call    cpuer
j070:   jc      j080    ;test "jc"
        jpo     j080    ;test "jpo"
        jp      j090    ;test "jp"
j080:   call    cpuer
j090:   adi     070h    ;a=76h,c=0,p=0,s=0,z=0
        jpo     j100    ;test "jpo"
        call    cpuer
j100:   jm      j110    ;test "jm"
        jz      j110    ;test "jz"
        jnc     j120    ;test "jnc"
j110:   call    cpuer
j120:   adi     081h    ;a=f7h,c=0,p=0,s=1,z=0
        jm      j130    ;test "jm"
        call    cpuer
j130:   jz      j140    ;test "jz"
        jc      j140    ;test "jc"
        jpo     j150    ;test "jpo"
j140:   call    cpuer
j150:   adi     0feh    ;a=f5h,c=1,p=1,s=1,z=0
        jc      j160    ;test "jc"
        call    cpuer
j160:   jz      j170    ;test "jz"
        jpo     j170    ;test "jpo"
        jm      aimm    ;test "jm"
j170:   call    cpuer
;
;
;
;test accumulator immediate instructions
;
aimm:   cpi     0       ;a=f5h,c=0,z=0
        jc      cpie    ;test "cpi" for re-set carry
        jz      cpie    ;test "cpi" for re-set zero
        cpi     0f5h    ;a=f5h,c=0,z=1
        jc      cpie    ;test "cpi" for re-set carry ("adi")
        jnz     cpie    ;test "cpi" for re-set zero
        cpi     0ffh    ;a=f5h,c=1,z=0
        jz      cpie    ;test "cpi" for re-set zero
        jc      acii    ;test "cpi" for set carry
cpie:   call    cpuer
acii:   aci     00ah    ;a=f5h+0ah+carry(1)=0,c=1
        aci     00ah    ;a=0+0ah+carry(0)=0bh,c=0
        cpi     00bh
        jz      suii    ;test "aci"
        call    cpuer
suii:   sui     00ch    ;a=ffh,c=0
        sui     00fh    ;a=f0h,c=1
        cpi     0f0h
        jz      sbii    ;test "sui"
        call    cpuer
sbii:   sbi     0f1h    ;a=f0h-0f1h-carry(0)=ffh,c=1
        sbi     00eh    ;a=ffh-oeh-carry(1)=f0h,c=0
        cpi     0f0h
        jz      anii    ;test "sbi"
        call    cpuer
anii:   ani     055h    ;a=f0h<and>55h=50h,c=0,p=1,s=0,z=0
        cpi     050h
        jz      orii    ;test "ani"
        call    cpuer
orii:   ori     03ah    ;a=50h<or>3ah=7ah,c=0,p=0,s=0,z=0
        cpi     07ah
        jz      xrii    ;test "ori"
        call    cpuer
xrii:   xri     00fh    ;a=7ah<xor>0fh=75h,c=0,p=0,s=0,z=0
        cpi     075h
        jz      c010    ;test "xri"
        call    cpuer
;
;
;
;test calls and returns
;
c010:   ani     0h      ;a=0,c=0,p=1,s=0,z=1
        cc      cpuer   ;test "cc"
        cpo     cpuer   ;test "cpo"
        cm      cpuer   ;test "cm"
        cnz     cpuer   ;test "cnz"
        cpi     0h
        jz      c020    ;a=0,c=0,p=0,s=0,z=1
        call    cpuer
c020:   sui     077h    ;a=89h,c=1,p=0,s=1,z=0
        cnc     cpuer   ;test "cnc"
        cpe     cpuer   ;test "cpe"
        cp      cpuer   ;test "cp"
        cz      cpuer   ;test "cz"
        cpi     089h
        jz      c030    ;test for "calls" taking branch
        call    cpuer
c030:   ani     0ffh    ;set flags back;
        cpo     cpoi    ;test "cpo"
        cpi     0d9h
        jz      movi    ;test "call" sequence success
        call    cpuer
cpoi:   rpe             ;test "rpe"
        adi     010h    ;a=99h,c=0,p=0,s=1,z=0
        cpe     cpei    ;test "cpe"
        adi     002h    ;a=d9h,c=0,p=0,s=1,z=0
        rpo             ;test "rpo"
        call    cpuer
cpei:   rpo             ;test "rpo"
        adi     020h    ;a=b9h,c=0,p=0,s=1,z=0
        cm      cmi     ;test "cm"
        adi     004h    ;a=d7h,c=0,p=1,s=1,z=0
        rpe             ;test "rpe"
        call    cpuer
cmi:    rp              ;test "rp"
        adi     080h    ;a=39h,c=1,p=1,s=0,z=0
        cp      tcpi    ;test "cp"
        adi     080h    ;a=d3h,c=0,p=0,s=1,z=0
        rm              ;test "rm"
        call    cpuer
tcpi:   rm              ;test "rm"
        adi     040h    ;a=79h,c=0,p=0,s=0,z=0
        cnc     cnci    ;test "cnc"
        adi     040h    ;a=53h,c=0,p=1,s=0,z=0
        rp              ;test "rp"
        call    cpuer
cnci:   rc              ;test "rc"
        adi     08fh    ;a=08h,c=1,p=0,s=0,z=0
        cc      cci     ;test "cc"
        sui     002h    ;a=13h,c=0,p=0,s=0,z=0
        rnc             ;test "rnc"
        call    cpuer
cci:    rnc             ;test "rnc"
        adi     0f7h    ;a=ffh,c=0,p=1,s=1,z=0
        cnz     cnzi    ;test "cnz"
        adi     0feh    ;a=15h,c=1,p=0,s=0,z=0
        rc              ;test "rc"
        call    cpuer
cnzi:   rz              ;test "rz"
        adi     001h    ;a=00h,c=1,p=1,s=0,z=1
        cz      czi     ;test "cz"
        adi     0d0h    ;a=17h,c=1,p=1,s=0,z=0
        rnz             ;test "rnz"
        call    cpuer
czi:    rnz             ;test "rnz"
        adi     047h    ;a=47h,c=0,p=1,s=0,z=0
        cpi     047h    ;a=47h,c=0,p=1,s=0,z=1
        rz              ;test "rz"
        call    cpuer
;
;
;
;test "mov","inr",and "dcr" instructions
;
movi:   mvi     a,077h
        inr     a
        mov     b,a
        inr     b
        mov     c,b
        dcr     c
        mov     d,c
        mov     e,d
        mov     h,e
        mov     l,h
        mov     a,l     ;test "mov" a,l,h,e,d,c,b,a
        dcr     a
        mov     c,a
        mov     e,c
        mov     l,e
        mov     b,l
        mov     d,b
        mov     h,d
        mov     a,h     ;test "mov" a,h,d,b,l,e,c,a
        mov     d,a
        inr     d
        mov     l,d
        mov     c,l
        inr     c
        mov     h,c
        mov     b,h
        dcr     b
        mov     e,b
        mov     a,e     ;test "mov" a,e,b,h,c,l,d,a
        mov     e,a
        inr     e
        mov     b,e
        mov     h,b
        inr     h
        mov     c,h
        mov     l,c
        mov     d,l
        dcr     d
        mov     a,d     ;test "mov" a,d,l,c,h,b,e,a
        mov     h,a
        dcr     h
        mov     d,h
        mov     b,d
        mov     l,b
        inr     l
        mov     e,l
        dcr     e
        mov     c,e
        mov     a,c     ;test "mov" a,c,e,l,b,d,h,a
        mov     l,a
        dcr     l
        mov     h,l
        mov     e,h
        mov     d,e
        mov     c,d
        mov     b,c
        mov     a,b
        cpi     077h
        cnz     cpuer   ;test "mov" a,b,c,d,e,h,l,a
;
;
;
;test arithmetic and logic instructions
;
        xra     a
        mvi     b,001h
        mvi     c,003h
        mvi     d,007h
        mvi     e,00fh
        mvi     h,01fh
        mvi     l,03fh
        add     b
        add     c
        add     d
        add     e
        add     h
        add     l
        add     a
        cpi     0f0h
        cnz     cpuer   ;test "add" b,c,d,e,h,l,a
        sub     b
        sub     c
        sub     d
        sub     e
        sub     h
        sub     l
        cpi     078h
        cnz     cpuer   ;test "sub" b,c,d,e,h,l
        sub     a
        cnz     cpuer   ;test "sub" a
        mvi     a,080h
        add     a
        mvi     b,001h
        mvi     c,002h
        mvi     d,003h
        mvi     e,004h
        mvi     h,005h
        mvi     l,006h
        adc     b
        mvi     b,080h
        add     b
        add     b
        adc     c
        add     b
        add     b
        adc     d
        add     b
        add     b
        adc     e
        add     b
        add     b
        adc     h
        add     b
        add     b
        adc     l
        add     b
        add     b
        adc     a
        cpi     037h
        cnz     cpuer   ;test "adc" b,c,d,e,h,l,a
        mvi     a,080h
        add     a
        mvi     b,001h
        sbb     b
        mvi     b,0ffh
        add     b
        sbb     c
        add     b
        sbb     d
        add     b
        sbb     e
        add     b
        sbb     h
        add     b
        sbb     l
        cpi     0e0h
        cnz     cpuer   ;test "sbb" b,c,d,e,h,l
        mvi     a,080h
        add     a
        sbb     a
        cpi     0ffh
        cnz     cpuer   ;test "sbb" a
        mvi     a,0ffh
        mvi     b,0feh
        mvi     c,0fch
        mvi     d,0efh
        mvi     e,07fh
        mvi     h,0f4h
        mvi     l,0bfh
        ana     a
        ana     c
        ana     d
        ana     e
        ana     h
        ana     l
        ana     a
        cpi     024h
        cnz     cpuer   ;test "ana" b,c,d,e,h,l,a
        xra     a
        mvi     b,001h
        mvi     c,002h
        mvi     d,004h
        mvi     e,008h
        mvi     h,010h
        mvi     l,020h
        ora     b
        ora     c
        ora     d
        ora     e
        ora     h
        ora     l
        ora     a
        cpi     03fh
        cnz     cpuer   ;test "ora" b,c,d,e,h,l,a
        mvi     a,0h
        mvi     h,08fh
        mvi     l,04fh
        xra     b
        xra     c
        xra     d
        xra     e
        xra     h
        xra     l
        cpi     0cfh
        cnz     cpuer   ;test "xra" b,c,d,e,h,l
        xra     a
        cnz     cpuer   ;test "xra" a
        mvi     b,044h
        mvi     c,045h
        mvi     d,046h
        mvi     e,047h
        mvi     h,temp0 >> 8          ;high byte of test memory location
        mvi     l,temp0 & 0ffh        ;low byte of test memory location
        mov     m,b
        mvi     b,0h
        mov     b,m
        mvi     a,044h
        cmp     b
        cnz     cpuer   ;test "mov" m,b and b,m
        mov     m,d
        mvi     d,0h
        mov     d,m
        mvi     a,046h
        cmp     d
        cnz     cpuer   ;test "mov" m,d and d,m
        mov     m,e
        mvi     e,0h
        mov     e,m
        mvi     a,047h
        cmp     e
        cnz     cpuer   ;test "mov" m,e and e,m
        mov     m,h
        mvi     h,temp0 >> 8
        mvi     l,temp0 & 0ffh
        mov     h,m
        mvi     a,temp0 >> 8
        cmp     h
        cnz     cpuer   ;test "mov" m,h and h,m
        mov     m,l
        mvi     h,temp0 >> 8
        mvi     l,temp0 & 0ffh
        mov     l,m
        mvi     a,temp0 & 0ffh
        cmp     l
        cnz     cpuer   ;test "mov" m,l and l,m
        mvi     h,temp0 >> 8
        mvi     l,temp0 & 0ffh
        mvi     a,032h
        mov     m,a
        cmp     m
        cnz     cpuer   ;test "mov" m,a
        add     m
        cpi     064h
        cnz     cpuer   ;test "add" m
        xra     a
        mov     a,m
        cpi     032h
        cnz     cpuer   ;test "mov" a,m
        mvi     h,temp0 >> 8
        mvi     l,temp0 & 0ffh
        mov     a,m
        sub     m
        cnz     cpuer   ;test "sub" m
        mvi     a,080h
        add     a
        adc     m
        cpi     033h
        cnz     cpuer   ;test "adc" m
        mvi     a,080h
        add     a
        sbb     m
        cpi     0cdh
        cnz     cpuer   ;test "sbb" m
        ana     m
        cnz     cpuer   ;test "ana" m
        mvi     a,025h
        ora     m
        cpi     037h
        cnz     cpuer   ;test "ora" m
        xra     m
        cpi     005h
        cnz     cpuer   ;test "xra" m
        mvi     m,055h
        inr     m
        dcr     m
        add     m
        cpi     05ah
        cnz     cpuer   ;test "inr","dcr",and "mvi" m
        lxi     b,012ffh
        lxi     d,012ffh
        lxi     h,012ffh
        inx     b
        inx     d
        inx     h
        mvi     a,013h
        cmp     b
        cnz     cpuer   ;test "lxi" and "inx" b
        cmp     d
        cnz     cpuer   ;test "lxi" and "inx" d
        cmp     h
        cnz     cpuer   ;test "lxi" and "inx" h
        mvi     a,0h
        cmp     c
        cnz     cpuer   ;test "lxi" and "inx" b
        cmp     e
        cnz     cpuer   ;test "lxi" and "inx" d
        cmp     l
        cnz     cpuer   ;test "lxi" and "inx" h
        dcx     b
        dcx     d
        dcx     h
        mvi     a,012h
        cmp     b
        cnz     cpuer   ;test "dcx" b
        cmp     d
        cnz     cpuer   ;test "dcx" d
        cmp     h
        cnz     cpuer   ;test "dcx" h
        mvi     a,0ffh
        cmp     c
        cnz     cpuer   ;test "dcx" b
        cmp     e
        cnz     cpuer   ;test "dcx" d
        cmp     l
        cnz     cpuer   ;test "dcx" h
        sta     temp0
        xra     a
        lda     temp0
        cpi     0ffh
        cnz     cpuer   ;test "lda" and "sta"
        lhld    tempp
        shld    temp0
        lda     tempp
        mov     b,a
        lda     temp0
        cmp     b
        cnz     cpuer   ;test "lhld" and "shld"
        lda     tempp+1
        mov     b,a
        lda     temp0+1
        cmp     b
        cnz     cpuer   ;test "lhld" and "shld"
        mvi     a,0aah
        sta     temp0
        mov     b,h
        mov     c,l
        xra     a
        ldax    b
        cpi     0aah
        cnz     cpuer   ;test "ldax" b
        inr     a
        stax    b
        lda     temp0
        cpi     0abh
        cnz     cpuer   ;test "stax" b
        mvi     a,077h
        sta     temp0
        lhld    tempp
        lxi     d,00000h
        xchg
        xra     a
        ldax    d
        cpi     077h
        cnz     cpuer   ;test "ldax" d and "xchg"
        xra     a
        add     h
        add     l
        cnz     cpuer   ;test "xchg"
        mvi     a,0cch
        stax    d
        lda     temp0
        cpi     0cch
        stax    d
        lda     temp0
        cpi     0cch
        cnz     cpuer   ;test "stax" d
        lxi     h,07777h
        dad     h
        mvi     a,0eeh
        cmp     h
        cnz     cpuer   ;test "dad" h
        cmp     l
        cnz     cpuer   ;test "dad" h
        lxi     h,05555h
        lxi     b,0ffffh
        dad     b
        mvi     a,055h
        cnc     cpuer   ;test "dad" b
        cmp     h
        cnz     cpuer   ;test "dad" b
        mvi     a,054h
        cmp     l
        cnz     cpuer   ;test "dad" b
        lxi     h,0aaaah
        lxi     d,03333h
        dad     d
        mvi     a,0ddh
        cmp     h
        cnz     cpuer   ;test "dad" d
        cmp     l
        cnz     cpuer   ;test "dad" b
        stc
        cnc     cpuer   ;test "stc"
        cmc
        cc      cpuer   ;test "cmc
        mvi     a,0aah
        cma     
        cpi     055h
        cnz     cpuer   ;test "cma"
        ora     a       ;re-set auxiliary carry
        daa
        cpi     055h
        cnz     cpuer   ;test "daa"
        mvi     a,088h
        add     a
        daa
        cpi     076h
        cnz     cpuer   ;test "daa"
        xra     a
        mvi     a,0aah
        daa
        cnc     cpuer   ;test "daa"
        cpi     010h
        cnz     cpuer   ;test "daa"
        xra     a
        mvi     a,09ah
        daa
        cnc     cpuer   ;test "daa"
        cnz     cpuer   ;test "daa"
        stc
        mvi     a,042h
        rlc
        cc      cpuer   ;test "rlc" for re-set carry
        rlc
        cnc     cpuer   ;test "rlc" for set carry
        cpi     009h
        cnz     cpuer   ;test "rlc" for rotation
        rrc
        cnc     cpuer   ;test "rrc" for set carry
        rrc
        cpi     042h
        cnz     cpuer   ;test "rrc" for rotation
        ral
        ral
        cnc     cpuer   ;test "ral" for set carry
        cpi     008h
        cnz     cpuer   ;test "ral" for rotation
        rar
        rar
        cc      cpuer   ;test "rar" for re-set carry
        cpi     002h
        cnz     cpuer   ;test "rar" for rotation
        lxi     b,01234h
        lxi     d,0aaaah
        lxi     h,05555h
        xra     a
        push    b
        push    d
        push    h
        push    psw
        lxi     b,00000h
        lxi     d,00000h
        lxi     h,00000h
        mvi     a,0c0h
        adi     0f0h
        pop     psw
        pop     h
        pop     d
        pop     b
        cc      cpuer   ;test "push psw" and "pop psw"
        cnz     cpuer   ;test "push psw" and "pop psw"
        cpo     cpuer   ;test "push psw" and "pop psw"
        cm      cpuer   ;test "push psw" and "pop psw"
        mvi     a,012h
        cmp     b
        cnz     cpuer   ;test "push b" and "pop b"
        mvi     a,034h
        cmp     c
        cnz     cpuer   ;test "push b" and "pop b"
        mvi     a,0aah
        cmp     d
        cnz     cpuer   ;test "push d" and "pop d"
        cmp     e
        cnz     cpuer   ;test "push d" and "pop d"
        mvi     a,055h
        cmp     h
        cnz     cpuer   ;test "push h" and "pop h"
        cmp     l
        cnz     cpuer   ;test "push h" and "pop h"
        lxi     h,00000h
        dad     sp
        shld    savstk  ;save the "old" stack-pointer;
        lxi     sp,temp4
        dcx     sp
        dcx     sp
        inx     sp
        dcx     sp
        mvi     a,055h
        sta     temp2
        cma
        sta     temp3
        pop     b
        cmp     b
        cnz     cpuer   ;test "lxi","dad","inx",and "dcx" sp
        cma
        cmp     c
        cnz     cpuer   ;test "lxi","dad","inx", and "dcx" sp
        lxi     h,temp4
        sphl
        lxi     h,07733h
        dcx     sp
        dcx     sp
        xthl
        lda     temp3
        cpi     077h
        cnz     cpuer   ;test "sphl" and "xthl"
        lda     temp2
        cpi     033h
        cnz     cpuer   ;test "sphl" and "xthl"
        mvi     a,055h
        cmp     l
        cnz     cpuer   ;test "sphl" and "xthl"
        cma
        cmp     h
        cnz     cpuer   ;test "sphl" and "xthl"
        lhld    savstk  ;restore the "old" stack-pointer
        sphl
        lxi     h,cpuok
        pchl            ;test "pchl"

cpuer:  lxi h, errmsg
        call puts
        pop h
        mov a, h
        call hexb
        mov a, l
        call hexb
        hlt             ; stop here

cpuok:  lxi h, okmsg
        call puts
        hlt             ; stop here - no trap

okmsg:  db "OK", 0ah, 0dh, 0
errmsg: db "ERROR AT: ", 0
;
; Data area in program space
;
tempp:  dw      temp0   ;pointer used to test "lhld","shld",
                        ; and "ldax" instructions
;
; Data area in variable space
;
temp0:  ds      1       ;temporary storage for cpu test memory locations
temp1:  ds      1       ;temporary storage for cpu test memory locations
temp2:  ds      1       ;temporary storage for cpu test memory locations
temp3:  ds      1       ;temporary storage for cpu test memory locations
temp4:  ds      1       ;temporary storage for cpu test memory locations
savstk: ds      2       ;temporary stack-pointer storage location

        ds      256     ;de-bug stack pointer storage area
stack:  ds      2
        end
