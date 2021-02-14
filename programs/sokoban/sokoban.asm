; Sokoban/Pusher
; --------------
; A clone of the old DOS game called "pusher.exe".
; Copyright (c) 2012 by Alexander Demin
;
; Note: The implementation isn't quite portable because it uses the RK86
;       Monitor variable at 7600h containing the address of the cursor
;       position in video memory.

monitor_puthex    equ 0f815h   ; Print A in hex.
monitor_putchar   equ 0f809h   ; Print C as a character.
monitor_putstr    equ 0f818h   ; Print 0-terminated string from HL.
monitor_inkey     equ 0f803h   ; Input a key to A.
monitor_warm_exit equ 0f86ch

monitor32_cursor_addr equ 7600h

  org 0h

  lxi sp, 4000h               ; A "far away" value.
  xra a
  sta level

selector_cls:
  mvi c, 1fh
  call monitor_putchar

  lxi h, copyright_msg
  call monitor_putstr

selector:
  lxi h, number_of_maze_msg
  call monitor_putstr
  lda level
  inr a
  call print_dec
  call monitor_inkey
  cpi 8
  jz prev
  cpi 18h
  jz next
  cpi ' '
  jz game
  cpi '.'
  jz monitor_warm_exit
  jmp selector

prev:
  lxi h, level
  dcr m
  jp selector
  mvi m, 59
  jmp selector

next:
  lxi h, level
  inr m
  mvi a, 59
  cmp m
  jp selector
  mvi m, 0
  jmp selector

level:
  db 0

game:
  lda level
  call print_level
game_inkey:
  call check_barrels
  ora a
  jz end_game
  call monitor_inkey
  lxi d, 0ffffh   ; -1
  cpi 8
  jz move
  lxi d, 1
  cpi 18h
  jz move
  lxi d, 0ffb2h   ; -4eh 
  cpi 19h
  jz move
  lxi d, 4eh
  cpi 1ah
  jz move
  cpi ' '
  jz selector_cls
  jmp game_inkey

end_game:
  lhld player_addr
  mvi m, ' '
  call monitor_inkey
  lxi h, congratulations_msg
  call monitor_putstr
  call monitor_inkey
  mvi c, 1fh
  call monitor_putchar
  jmp next

move:
  lhld player_addr
  dad d
  mov a, m
  cpi ' '
  jz go_ahead
  cpi '.'
  jz go_ahead
  cpi '*'
  jz barrel_ahead
  cpi '&'
  jz barrel_ahead
  jmp game_inkey

go_ahead:
  lhld player_addr
  mvi m, ' '
  dad d
  mvi m, 9
  shld player_addr
  jmp game_inkey

barrel_ahead:
  dad d
  mov a, m
  cpi ' '
  mvi b, '*'
  jz shift_barrel
  cpi '.'
  mvi b, '&'
  jz shift_barrel
  jmp game_inkey

shift_barrel:
  lhld player_addr
  mvi m, ' '
  dad d
  shld player_addr
  mvi m, 9
  dad d
  mov m, b         ; '*' or '&'
  jmp game_inkey

print_level:
  push psw
  push b
  push d
  push h

  mvi c, 1fh
  call monitor_putchar

  push psw
  xra a
  sta barrel_count
  lxi h, barrels
  shld current_barrel
  pop psw

  mov l, a
  mvi h, 0
  dad h
  lxi d, levels
  dad d

  mov a, m
  inx h
  mov h, m
  mov l, a

  mov e, m
  mvi a, 64
  sub e
  ora a
  rar
  sta offset_x

  inx h
  mov d, m
  mvi a, 25
  sub d
  ora a
  rar
  sta offset_y

  push h
  lhld offset_xy
  shld player_xy
  pop h

  mov b, e
  mvi c, 0                             ; The initial repeat counter is 0.
  mvi a, 01h                   
  sta extract_bit_mask                 ; The initial bit mask is 0x01.

print_level_height_loop:
  push h
  lhld offset_xy
  call set_cursor
  inr l
  shld offset_xy
  pop h

print_level_width_loop:
  call extract_byte
  cpi '.'
  jz mark_barrel_place
  cpi '&'
  jz mark_barrel_place

print_level_character:
  push b
  mov c, a
  call monitor_putchar
  pop b
  dcr e
  jnz print_level_width_loop
  mov e, b
  dcr d
  jnz print_level_height_loop

  inx h
  mov a, m
  inx h
  mov l, m
  mov h, a
  xchg

  lhld player_xy
  dad d
  call set_cursor
  lhld monitor32_cursor_addr
  shld player_addr

  mvi m, 9

  pop h
  pop d
  pop b
  pop psw
  ret

mark_barrel_place:
  push h
  push d
  push psw

  lhld monitor32_cursor_addr
  xchg

  lhld current_barrel
  mov m, e
  inx h
  mov m, d
  inx h
  shld current_barrel

  lda barrel_count
  inr a
  sta barrel_count

  pop psw
  pop d
  pop h
  jmp print_level_character

check_barrels:
  push h
  push d
  push b
  lda barrel_count
  mov c, a
  mov b, a
  lxi h, barrels
check_barrels_loop:
  mov e, m
  inx h
  mov d, m
  inx h
  xchg
  mov a, m
  cpi ' '
  jz check_barrels_restore
  cpi '&'
  jnz check_barrels_loop_prolog
  dcr b
check_barrels_loop_prolog:
  xchg
  dcr c
  jnz check_barrels_loop
  mov a, b
  pop b
  pop d
  pop h
  ret

check_barrels_restore:
  mvi m, '.'
  jmp check_barrels_loop_prolog

; H - X
; L - Y  
set_cursor:
  push h
  push d
  push b
  push psw
  lxi d, 2020h
  dad d
  shld set_cursor_msg + 2
  lxi h, set_cursor_msg
  call monitor_putstr
  pop psw
  pop b
  pop d
  pop h
  ret

set_cursor_msg:
  db 1bh, 59h, 20h, 20h, 0

player_xy dw 0
player_addr dw 0

offset_xy:
offset_y db 0
offset_x db 0

; C is the current repeat counter.
extract_byte:
  lda current_byte
  dcr c
  rp                            ; return if c >= 0
  inr c                         ; C = 0
  call extract_bit
  jz extract_byte_counter_1     ; counter is 1

  ; Decode the counter from 4 bits: 1 D3 D2 D1 
  ; N = D3*4 + D2*2 + D1 + 2
  xra a
  call extract_bit
  jz extract_byte_d3_0
  ori 04h
extract_byte_d3_0:
  call extract_bit
  jz extract_byte_d2_0
  ori 02h
extract_byte_d2_0:
  call extract_bit
  jz extract_byte_d1_0
  ori 01h
extract_byte_d1_0:
  inr a
  mov c, a

extract_byte_counter_1:
  call extract_bit
  jz extract_byte_value_0

  mvi a, '*'      ; 10
  sta current_byte
  call extract_bit
  rz

  call extract_bit
  mvi a, '.'      ; 110
  sta current_byte
  rz
  mvi a, '&'      ; 111
  sta current_byte
  ret

extract_byte_value_0:
  call extract_bit
  mvi a, ' '      ; 00
  sta current_byte
  rz
  mvi a, 17h      ; 01
  sta current_byte
  ret 

current_byte:
  db '-'

extract_bit:
  sta extract_bit_keep_a
  lda extract_bit_mask
  cpi 01h
  jnz extract_bit_1
  inx h
extract_bit_1:
  rrc
  sta extract_bit_mask
  ana m
  lda extract_bit_keep_a
  ret

extract_bit_keep_a:
  db 0

extract_bit_mask:
  db 01h

print_dec:
  push psw
  push b
  mvi b, 0ffh
print_dec_loop:
  inr b
  sui 10
  jp print_dec_loop
  adi 10
  sta print_dec_tmp
  mvi a, '0'
  add b
  mov c, a
  cpi '0'
  jnz print_dec_skip_0
  mvi c, ' '
print_dec_skip_0:
  call monitor_putchar
  lda print_dec_tmp
  adi '0'
  mov c, a
  call monitor_putchar
  pop b
  pop psw
  ret

print_dec_tmp db 0

number_of_maze_msg:
  db 1bh, 59h, (25/2) + 20h, (64-number_of_maze_msg_sz)/2 + 20h
number_of_maze_text:
  db "nomer urownq: "
number_of_maze_msg_sz equ $-number_of_maze_text
  db 0

congratulations_msg:
  db 1fh, 1bh, 59h, (25/2) + 20h, (64-congratulations_msg_sz)/2 + 20h
congratulations_text:
  db "pozdrawlq` !!!"
congratulations_msg_sz equ $-congratulations_text
  db 0

copyright_msg:
  db 1fh, 1bh, 59h, 23 + 20h, (64-copyright_msg_sz)/2 + 20h
copyright_text:
  db "sokoban, awtor aleksandr demin, (C) 2012"
copyright_msg_sz equ $-copyright_text
  db 0

levels:
  dw level_01
  dw level_02
  dw level_03
  dw level_04
  dw level_05
  dw level_06
  dw level_07
  dw level_08
  dw level_09
  dw level_10
  dw level_11
  dw level_12
  dw level_13
  dw level_14
  dw level_15
  dw level_16
  dw level_17
  dw level_18
  dw level_19
  dw level_20
  dw level_21
  dw level_22
  dw level_23
  dw level_24
  dw level_25
  dw level_26
  dw level_27
  dw level_28
  dw level_29
  dw level_30
  dw level_31
  dw level_32
  dw level_33
  dw level_34
  dw level_35
  dw level_36
  dw level_37
  dw level_38
  dw level_39
  dw level_40
  dw level_41
  dw level_42
  dw level_43
  dw level_44
  dw level_45
  dw level_46
  dw level_47
  dw level_48
  dw level_49
  dw level_50
  dw level_51
  dw level_52
  dw level_53
  dw level_54
  dw level_55
  dw level_56
  dw level_57
  dw level_58
  dw level_59
  dw level_60

level_01        db 16h, 0Bh, 0A2h, 0DFh, 38h, 32h, 1Fh, 38h, 2Ah, 3, 0E6h
                db 12h, 0C0h, 0A5h, 0F2h, 83h, 2, 81h, 3, 0E4h, 12h, 82h
                db 25h, 6, 0CDh, 64h, 22h, 51h, 0ACh, 11h, 0A1h, 0Ah, 5
                db 0E5h, 11h, 0B1h, 14h, 82h, 29h, 82h, 31h, 0A0h, 0E1h
                db 2Ch, 18h, 0D1h, 0CFh, 80h, 0Ch, 8
level_02        db 0Eh, 0Ah, 0F6h, 58h, 0Ch, 68h, 0Dh, 94h, 0C6h, 80h
                db 85h, 2, 82h, 18h, 0D0h, 15h, 4Ch, 10h, 0C6h, 0C2h, 18h
                db 21h, 8Dh, 1, 6, 4, 39h, 10h, 0A0h, 81h, 80h, 85h, 2
                db 8, 20h, 60h, 34h, 1Bh, 0Ch, 1Eh, 0CAh, 7, 4
level_03        db 11h, 0Ah, 0E3h, 9Fh, 0Eh, 7, 0C2h, 11h, 42h, 1Fh, 8
                db 50h, 23h, 0E0h, 85h, 4, 0Ch, 1Eh, 84h, 8, 0A6h, 0B4h
                db 10h, 85h, 2, 82h, 59h, 0D4h, 28h, 14h, 90h, 0D6h, 83h
                db 0DFh, 7Ch, 0Eh, 1
level_04        db 16h, 0Dh, 0F2h, 0CEh, 7Ch, 0B0h, 0C1h, 58h, 0C9h, 0ECh
                db 0B0h, 56h, 32h, 1Ah, 0Ch, 8, 29h, 2Bh, 19h, 8, 98h
                db 0A8h, 10h, 30h, 56h, 32h, 18h, 15h, 88h, 18h, 2Bh, 19h
                db 8, 88h, 14h, 10h, 5Eh, 0CBh, 2, 6, 0C3h, 0A1h, 90h
                db 8Fh, 74h, 34h, 28h, 21h, 0F2h, 42h, 22h, 31h, 40h, 7Ch
                db 90h, 0C8h, 64h, 87h, 0C9h, 3Dh, 0F2h, 80h, 8, 0Ah
level_05        db 11h, 0Dh, 0E2h, 0DFh, 24h, 32h, 5Bh, 0C1h, 5, 43h, 1
                db 0E0h, 0D8h, 87h, 0A4h, 4Bh, 24h, 35h, 0A0h, 84h, 28h
                db 15h, 35h, 0A8h, 42h, 21h, 8, 35h, 0A0h, 85h, 40h, 0A0h
                db 23h, 0D8h, 14h, 10h, 0F8h, 42h, 0Ah, 3, 0E4h, 0A2h
                db 10h, 7Ch, 80h, 0D0h, 7Ch, 83h, 10h, 0Eh, 7
level_06        db 0Ch, 0Bh, 0C6h, 9, 41h, 8Dh, 1, 10h, 89h, 63h, 41h
                db 2Ch, 90h, 0C6h, 0B2h, 21h, 0Ch, 68h, 8, 21h, 8, 63h
                db 4Ah, 8, 42h, 0D0h, 81h, 50h, 19h, 0Ch, 8, 84h, 0Ch
                db 84h, 28h, 14h, 6, 43h, 4, 32h, 19h, 3Dh, 9, 1
level_07        db 0Dh, 0Ch, 0D2h, 0D8h, 35h, 92h, 90h, 60h, 84h, 44h
                db 21h, 0A1h, 61h, 0Ch, 0Ah, 9, 64h, 0A4h, 5Ah, 0A9h, 0Ah
                db 9, 44h, 62h, 8, 41h, 4, 27h, 10h, 68h, 96h, 71h, 4
                db 44h, 8, 33h, 88h, 30h, 4Ah, 2Dh, 14h, 0F8h, 5, 2
level_08        db 10h, 11h, 82h, 9Fh, 24h, 30h, 7Bh, 0Ch, 6, 85h, 22h
                db 8, 18h, 8, 44h, 20h, 60h, 50h, 18h, 0Ch, 8, 28h, 0Dh
                db 14h, 84h, 41h, 82h, 91h, 8, 28h, 20h, 0A0h, 86h, 48h
                db 68h, 40h, 0A3h, 21h, 12h, 0C0h, 0A8h, 41h, 4, 8, 0A6h
                db 0Fh, 60h, 96h, 9, 78h, 38h, 1Eh, 0Eh, 7, 83h, 98h, 0F0h
                db 73h, 1Eh, 0Eh, 63h, 0C7h, 38h, 0, 1, 6
level_09        db 11h, 12h, 0F0h, 6Bh, 0E0h, 30h, 4Eh, 38h, 5Bh, 4, 0E3h
                db 81h, 0C2h, 71h, 0C0h, 0C1h, 0Ch, 13h, 8Eh, 10h, 88h
                db 60h, 9Ch, 6Ch, 94h, 73h, 61h, 13h, 8, 6Ch, 0B6h, 4
                db 10h, 0D6h, 42h, 82h, 90h, 0C9h, 0Ch, 0Ah, 5, 42h, 81h
                db 0Dh, 44h, 41h, 0Bh, 6Ch, 21h, 50h, 7Ch, 0A4h, 4Bh, 0E4h
                db 86h, 3, 0E5h, 6, 3, 0E5h, 6, 3, 0E5h, 14h, 0D8h, 1
                db 0Ah
level_10        db 15h, 14h, 0F2h, 0CAh, 7Ch, 93h, 18h, 0Fh, 92h, 1Dh
                db 0Fh, 92h, 18h, 29h, 12h, 0C1h, 2Ch, 16h, 89h, 68h, 22h
                db 11h, 4Ch, 93h, 3, 41h, 4, 45h, 24h, 41h, 48h, 6Bh, 4Bh
                db 4, 0C6h, 85h, 1, 0BDh, 8, 52h, 11h, 10h, 88h, 1Bh, 0D4h
                db 0C8h, 60h, 54h, 1Bh, 0C6h, 3, 21h, 8, 20h, 81h, 0BCh
                db 60h, 23h, 51h, 2Dh, 0E3h, 1, 90h, 0C0h, 82h, 80h, 0DEh
                db 30h, 4Ah, 8, 88h, 20h, 0B5h, 0A0h, 83h, 2, 0C0h, 0F0h
                db 41h, 13h, 9, 81h, 0E0h, 83h, 0A1h, 7, 82h, 3Dh, 7, 83h
                db 0E4h, 7, 8Fh, 69h, 0A0h, 2, 5
level_11        db 13h, 0Fh, 0F0h, 53h, 0E0h, 0A4h, 18h, 0Fh, 12h, 0C1h
                db 2Ah, 7, 48h, 70h, 50h, 1Ch, 21h, 81h, 8, 0A1h, 10h
                db 0E0h, 60h, 2Ah, 1Bh, 0Eh, 4, 10h, 84h, 40h, 89h, 6Ch
                db 32h, 20h, 60h, 21h, 0Fh, 68h, 30h, 44h, 0Ch, 96h, 88h
                db 42h, 0F2h, 16h, 0A2h, 58h, 3Dh, 8Ch, 23h, 11h, 4Eh
                db 86h, 71h, 63h, 0E4h, 86h, 0F1h, 0F2h, 4Dh, 7Ch, 90h
                db 7, 3
level_12        db 0Dh, 10h, 83h, 0DAh, 0Bh, 0B3h, 97h, 67h, 34h, 16h
                db 76h, 76h, 76h, 34h, 17h, 67h, 67h, 67h, 34h, 16h, 76h
                db 76h, 76h, 34h, 17h, 67h, 67h, 67h, 34h, 4Bh, 24h, 0B8h
                db 19h, 0Dh, 18h, 8Dh, 7Ch, 82h, 10h, 82h, 8, 20h, 84h
                db 0A1h, 4, 10h, 42h, 10h, 50h, 41h, 4, 11h, 80h, 0C8h
                db 82h, 90h, 0C0h, 60h, 0B6h, 3, 5, 32h, 52h, 0, 6, 0Dh
level_13        db 14h, 0Dh, 0A3h, 0DFh, 25h, 92h, 18h, 2Dh, 92h, 5Ch
                db 0Ch, 6, 4Bh, 60h, 88h, 14h, 0Ch, 6, 9, 0C2h, 10h, 60h
                db 44h, 28h, 41h, 5, 8Bh, 8, 60h, 84h, 15h, 1, 0A2h, 70h
                db 84h, 23h, 42h, 4, 10h, 58h, 0B0h, 86h, 88h, 60h, 85h
                db 4, 27h, 8, 42h, 10h, 0C8h, 60h, 28h, 0B1h, 61h, 28h
                db 8Ah, 5, 22h, 81h, 4Eh, 4, 15h, 6, 34h, 43h, 1, 6, 43h
                db 47h, 0A4h, 5Bh, 0E5h, 80h, 7, 4
level_14        db 11h, 0Dh, 0F7h, 50h, 7Ch, 0B0h, 82h, 8, 0C6h, 0C2h
                db 8, 30h, 20h, 82h, 8, 0C0h, 41h, 6, 44h, 14h, 90h, 89h
                db 41h, 5, 4, 14h, 0B3h, 0A1h, 6, 44h, 14h, 10h, 0CEh
                db 84h, 4Bh, 30h, 42h, 19h, 0D0h, 0D8h, 44h, 22h, 19h
                db 0D8h, 0C9h, 8, 86h, 71h, 0A2h, 0DBh, 25h, 0E0h, 0D8h
                db 7Ch, 1Ah, 0C0h, 7, 4
level_15        db 11h, 11h, 0D2h, 9Fh, 5, 30h, 1Fh, 21h, 80h, 0C0h, 7Ch
                db 30h, 20h, 81h, 0D2h, 50h, 54h, 94h, 0D0h, 60h, 50h
                db 42h, 0A4h, 34h, 18h, 0Ch, 88h, 10h, 8Dh, 6, 3, 82h
                db 14h, 88h, 45h, 2Ah, 1Bh, 8, 21h, 1Bh, 0C4h, 19h, 8
                db 30h, 29h, 0CEh, 0C1h, 11h, 6Ch, 6, 0F1h, 90h, 0C0h
                db 64h, 94h, 6Bh, 1, 11h, 40h, 60h, 3Ah, 18h, 0Dh, 87h
                db 4Ch, 64h, 3Eh, 49h, 6Eh, 80h, 6, 6
level_16        db 0Eh, 0Fh, 0B7h, 0C3h, 24h, 3Ch, 1Ah, 0Ch, 14h, 0C0h
                db 42h, 82h, 98h, 0Ch, 6, 8, 82h, 91h, 18h, 25h, 80h, 0AAh
                db 21h, 80h, 0C1h, 0Ch, 8, 21h, 8, 21h, 41h, 8, 84h, 31h
                db 6, 2, 0A1h, 50h, 16h, 22h, 59h, 14h, 68h, 58h, 0C0h
                db 68h, 2Ch, 0F3h, 8Ch, 4, 44h, 0Dh, 0E3h, 1, 83h, 0D8h
                db 0Ch, 7, 0C1h, 4Fh, 0, 3, 5
level_17        db 12h, 10h, 0D3h, 5Bh, 35h, 0B0h, 0D8h, 6Ch, 21h, 4, 0Dh
                db 86h, 20h, 64h, 0F4h, 11h, 2Eh, 68h, 64h, 20h, 0C8h
                db 0B3h, 42h, 8, 20h, 89h, 73h, 59h, 2Ch, 94h, 89h, 41h
                db 52h, 0C0h, 54h, 86h, 5, 1, 4, 18h, 10h, 9Ah, 2, 14h
                db 20h, 83h, 22h, 8, 4Bh, 10h, 20h, 8Bh, 6Ch, 52h, 10h
                db 6Ch, 94h, 4Bh, 21h, 7, 43h, 61h, 90h, 0E9h, 0CCh, 7
                db 0CBh, 29h, 0, 0Ah, 2
level_18        db 16h, 0Dh, 0C3h, 0D9h, 7Ch, 6, 6, 82h, 19h, 0Fh, 80h
                db 82h, 0DAh, 1Bh, 31h, 10h, 0CEh, 22h, 99h, 21h, 82h
                db 19h, 0D4h, 0D9h, 68h, 42h, 19h, 0D4h, 20h, 60h, 50h
                db 43h, 64h, 61h, 8, 22h, 11h, 0Ch, 16h, 0A9h, 51h, 0Ah
                db 3, 21h, 10h, 89h, 60h, 34h, 42h, 84h, 40h, 83h, 1, 92h
                db 20h, 41h, 8, 10h, 0A1h, 6, 3, 0E7h, 86h, 0Fh, 79h, 80h
                db 0F9h, 0E5h, 20h, 0Fh, 2
level_19        db 1Ch, 14h, 0E3h, 1Fh, 3Ch, 0A0h, 0D1h, 4Fh, 9Ch, 5Ah
                db 14h, 87h, 0CEh, 0Ch, 90h, 0D1h, 4Fh, 96h, 10h, 0A1h
                db 82h, 1Ah, 0Fh, 96h, 19h, 0Ch, 16h, 83h, 0E5h, 84h, 18h
                db 82h, 0A0h, 83h, 0E5h, 86h, 4, 10h, 94h, 10h, 7Ch, 0B0h
                db 83h, 22h, 80h, 82h, 0Fh, 96h, 10h, 60h, 28h, 0C8h, 41h
                db 0F2h, 88h, 45h, 32h, 10h, 41h, 0F2h, 83h, 2, 82h, 0D0h
                db 41h, 14h, 0E9h, 0Dh, 0Ah, 0C5h, 4, 0B0h, 7Bh, 4, 0A1h
                db 4, 42h, 6, 4Bh, 0D0h, 0D9h, 0Eh, 6, 8, 60h, 37h, 0A1h
                db 15h, 51h, 8Ah, 86h, 42h, 0D0h, 0B4h, 0B4h, 43h, 0E5h
                db 86h, 0B1h, 10h, 0C1h, 0EEh, 32h, 56h, 30h, 18h, 0Fh
                db 94h, 5Bh, 4, 30h, 53h, 0E7h, 14h, 80h, 0Ch, 1
level_20        db 14h, 14h, 0D3h, 0D9h, 78h, 3Fh, 98h, 0E1h, 2Bh, 16h
                db 2Ch, 58h, 0C6h, 38h, 19h, 3Fh, 1Ch, 0Ch, 8, 20h, 83h
                db 0B3h, 0B1h, 0B3h, 51h, 0ACh, 14h, 0C8h, 68h, 86h, 3
                db 4, 34h, 20h, 68h, 21h, 8, 41h, 80h, 0A2h, 25h, 12h
                db 0A9h, 25h, 0Ah, 4, 14h, 84h, 20h, 82h, 10h, 0C0h, 42h
                db 10h, 0E8h, 50h, 86h, 45h, 4Ah, 0A5h, 43h, 5, 0B0h, 43h
                db 21h, 0A0h, 0C0h, 64h, 28h, 43h, 21h, 4, 45h, 1, 90h
                db 0C8h, 42h, 6, 5, 41h, 92h, 50h, 44h, 40h, 0C0h, 84h
                db 0B6h, 10h, 68h, 21h, 8, 74h, 23h, 90h, 78h, 3Eh, 3
                db 0C7h, 0B2h, 0C8h, 6, 4
level_21        db 10h, 0Eh, 93h, 0D3h, 81h, 8Dh, 1, 90h, 0E0h, 63h, 60h
                db 70h, 31h, 0A0h, 30h, 53h, 26h, 0B0h, 18h, 21h, 80h
                db 0F9h, 21h, 80h, 0C0h, 60h, 86h, 3, 5, 0A2h, 18h, 29h
                db 12h, 0C0h, 0A0h, 0B4h, 18h, 21h, 4, 28h, 14h, 4, 28h
                db 21h, 81h, 40h, 0A4h, 32h, 62h, 21h, 1Ah, 0D0h, 68h
                db 3Eh, 0Ch, 74h, 2, 0Ah
level_22        db 16h, 14h, 0F2h, 4Ah, 74h, 0F6h, 58h, 2Dh, 90h, 0D0h
                db 60h, 30h, 28h, 0Ch, 90h, 0C0h, 42h, 8, 28h, 10h, 21h
                db 5, 21h, 82h, 14h, 14h, 86h, 2, 14h, 88h, 11h, 2Ch, 9Eh
                db 0CAh, 21h, 6, 4, 11h, 80h, 0E6h, 021h, 18h, 8, 32h
                db 18h, 0Eh, 68h, 41h, 80h, 0C1h, 8, 84h, 11h, 78h, 0C0h
                db 60h, 20h, 0E0h, 0B3h, 4, 0Ch, 4, 10h, 84h, 20h, 0E6h
                db 30h, 18h, 0Ch, 8, 23h, 1, 0CCh, 42h, 30h, 10h, 0A4h
                db 30h, 42h, 0ADh, 80h, 0C0h, 42h, 8, 52h, 10h, 50h, 20h
                db 8Ch, 10h, 83h, 62h, 8, 20h, 0A4h, 94h, 18h, 31h, 0Ah
                db 85h, 41h, 7, 0C2h, 35h, 4, 6Ah, 0Ah, 0F0h, 1Dh, 0Ch
                db 9Eh, 0C3h, 0A5h, 0BEh, 0, 0Bh, 4
level_23        db 19h, 0Eh, 0D3h, 5Fh, 3Ch, 30h, 18h, 29h, 0F3h, 2, 11h
                db 40h, 0C1h, 0Eh, 9Ch, 0C0h, 60h, 32h, 7Bh, 5Ah, 2, 11h
                db 40h, 0C0h, 8Ch, 6, 48h, 6Bh, 10h, 6Ch, 2Ah, 3, 84h
                db 31h, 8Bh, 50h, 8Ch, 4, 2Ah, 0Ah, 82h, 19h, 0D0h, 43h
                db 1, 40h, 0A8h, 0Ch, 6, 48h, 6Bh, 8, 42h, 36h, 2Fh, 75h
                db 80h, 0C4h, 54h, 7, 0CBh, 8, 46h, 3, 2, 3Eh, 58h, 60h
                db 30h, 19h, 0Fh, 96h, 53h, 5, 0BEh, 71h, 4Fh, 90h, 0
                db 5, 7
level_24        db 15h, 13h, 93h, 0D3h, 0E4h, 7, 0B5h, 3Ch, 16h, 2Ch, 6Bh
                db 18h, 0Fh, 7, 0B4h, 40h, 0F0h, 6Ch, 69h, 60h, 0A6h, 4Fh
                db 60h, 40h, 0C8h, 64h, 36h, 29h, 10h, 50h, 20h, 64h, 30h
                db 1Ah, 0Ch, 8, 23h, 1, 92h, 11h, 6Ch, 86h, 3, 1, 90h
                db 85h, 61h, 92h, 90h, 60h, 86h, 4, 64h, 22h, 18h, 0Ch
                db 6, 3, 44h, 2Ah, 5Ah, 0Ch, 10h, 82h, 15h, 8, 18h, 0Ch
                db 6, 42h, 2Dh, 0A0h, 88h, 41h, 10h, 88h, 68h, 28h, 83h
                db 2, 81h, 5, 21h, 0A0h, 83h, 2, 33h, 40h, 64h, 34h, 4Bh
                db 2, 0C2h, 0DCh, 21h, 80h, 0C0h, 60h, 3Eh, 41h, 0E9h
                db 0A0h, 5, 0Fh
level_25        db 17h, 11h, 0F3h, 0Ah, 7Ch, 0B3h, 18h, 2Dh, 0A3h, 5Dh
                db 0Ch, 86h, 83h, 82h, 8, 42h, 8, 20h, 0D0h, 60h, 0A4h
                db 28h, 0Dh, 8Ch, 68h, 38h, 20h, 41h, 10h, 0B1h, 63h, 44h
                db 2Ah, 94h, 10h, 42h, 16h, 2Ch, 68h, 36h, 1Ah, 29h, 69h
                db 68h, 21h, 49h, 8Ch, 5, 8Bh, 6Bh, 34h, 3Ah, 16h, 2Dh
                db 0Eh, 6, 82h, 8Ah, 95h, 83h, 42h, 29h, 6, 0EAh, 8, 9Dh
                db 8, 34h, 2Bh, 0Ch, 84h, 4Eh, 84h, 19h, 21h, 10h, 0D9h
                db 2Ch, 0E8h, 46h, 2Bh, 18h, 35h, 0E0h, 0D0h, 60h, 36h
                db 7Ah, 68h, 0A6h, 0C0h, 11h, 9
level_26        db 0Fh, 0Fh, 0F7h, 3, 0A1h, 0C0h, 0E9h, 4Ch, 90h, 8Ah
                db 41h, 80h, 0C9h, 8, 22h, 1Ah, 0Ch, 84h, 4Ch, 14h, 11h
                db 19h, 0Ch, 4, 42h, 14h, 6, 43h, 1, 10h, 0C0h, 87h, 30h
                db 4Ch, 11h, 80h, 83h, 24h, 32h, 56h, 20h, 83h, 21h, 6
                db 30h, 62h, 0Ch, 84h, 11h, 0Ch, 0E2h, 2Dh, 0Ah, 3, 38h
                db 0D9h, 0Ch, 96h, 0E1h, 6Dh, 0, 4, 4
level_27        db 17h, 0Dh, 1Eh, 0F3h, 81h, 9Dh, 21h, 0A0h, 0C9h, 2Ch
                db 90h, 0DEh, 81h, 42h, 8, 21h, 3, 21h, 0CCh, 60h, 50h
                db 18h, 14h, 6, 43h, 98h, 0C0h, 60h, 20h, 82h, 21h, 83h
                db 0D0h, 0A0h, 40h, 83h, 4, 0B0h, 1Bh, 0Ah, 85h, 8, 44h
                db 32h, 11h, 0Ch, 8Ah, 82h, 14h, 0Ah, 42h, 8, 30h, 42h
                db 25h, 6, 0Bh, 51h, 4, 10h, 84h, 56h, 29h, 15h, 84h, 10h
                db 0A8h, 50h, 0A1h, 0C8h, 23h, 5Ah, 21h, 0C2h, 5Dh, 31h
                db 0F0h, 0, 0Ah, 0Bh
level_28        db 0Fh, 11h, 0B3h, 5Eh, 0Ch, 6, 3, 0C1h, 0Ah, 43h, 0A4h
                db 0A2h, 10h, 68h, 0A4h, 28h, 8, 86h, 43h, 0A1h, 82h, 18h
                db 8, 41h, 52h, 10h, 30h, 11h, 10h, 30h, 18h, 11h, 80h
                db 0A8h, 14h, 85h, 40h, 44h, 30h, 44h, 64h, 88h, 4Ah, 22h
                db 80h, 0C0h, 60h, 42h, 1Bh, 29h, 0Ah, 8, 60h, 2Ah, 18h
                db 0D0h, 0C9h, 48h, 63h, 5Ah, 0D8h, 8, 0DDh, 0Dh, 6, 0B4h
                db 91h, 8Dh, 1Eh, 0C3h, 0, 6, 1
level_29        db 18h, 0Bh, 0F3h, 4Bh, 7Ch, 18h, 89h, 64h, 0A6h, 4Bh
                db 68h, 94h, 20h, 0A0h, 42h, 0D8h, 21h, 5, 5, 42h, 6, 48h
                db 6Bh, 49h, 10h, 41h, 40h, 0A4h, 2Ah, 58h, 0C0h, 88h
                db 41h, 92h, 55h, 8, 30h, 43h, 5Ah, 82h, 25h, 0A0h, 0D1h
                db 0Dh, 6Ah, 8, 86h, 5, 4, 0A8h, 43h, 1Bh, 18h, 14h, 6
                db 0Ah, 46h, 34h, 19h, 25h, 0D0h, 0F9h, 0EEh, 20h, 13h
                db 9
level_30        db 0Eh, 14h, 16h, 0F8h, 64h, 0D6h, 42h, 10h, 96h, 43h
                db 21h, 0Ah, 88h, 81h, 92h, 11h, 4Ch, 86h, 9, 41h, 80h
                db 89h, 60h, 32h, 18h, 8, 86h, 42h, 22h, 0A1h, 3, 21h
                db 90h, 82h, 10h, 0F4h, 19h, 0Ch, 4, 19h, 15h, 32h, 10h
                db 60h, 56h, 28h, 8, 86h, 4Bh, 44h, 23h, 0D3h, 4, 0B5h
                db 88h, 50h, 21h, 0Dh, 0E2h, 22h, 30h, 43h, 18h, 46h, 21h
                db 40h, 84h, 37h, 94h, 86h, 9, 60h, 0F4h, 8Ah, 7Ch, 8
                db 6
level_31        db 0Fh, 0Ch, 1Ah, 0F0h, 60h, 30h, 5Bh, 24h, 30h, 18h, 0Ch
                db 0E9h, 41h, 81h, 18h, 0Ch, 0E8h, 8, 21h, 3, 10h, 9Dh
                db 1, 6, 4, 60h, 33h, 83h, 10h, 64h, 21h, 7Ah, 56h, 88h
                db 21h, 2Ch, 6, 8, 81h, 90h, 8Ch, 60h, 86h, 20h, 70h, 38h
                db 43h, 87h, 20h, 0Dh, 9
level_32        db 12h, 10h, 82h, 9Fh, 2Ch, 30h, 7Bh, 64h, 30h, 43h, 1
                db 90h, 0D8h, 60h, 44h, 20h, 0A4h, 0A6h, 2, 0A0h, 50h
                db 10h, 82h, 30h, 53h, 2, 84h, 14h, 15h, 90h, 0C0h, 60h
                db 20h, 0C9h, 34h, 10h, 85h, 42h, 81h, 42h, 2Dh, 8, 20h
                db 51h, 80h, 0C0h, 64h, 86h, 9, 60h, 95h, 3, 41h, 80h
                db 0D6h, 0B0h, 0D1h, 4Eh, 6Ah, 70h, 35h, 0A9h, 0F0h, 0CEh
                db 87h, 0C9h, 0Ch, 0E3h, 0E5h, 16h, 0F8h, 0, 8, 2
level_33        db 0Dh, 0Fh, 0C2h, 9Bh, 2Dh, 80h, 0D1h, 0Dh, 88h, 0C9h
                db 8, 50h, 42h, 25h, 4, 20h, 81h, 0Ah, 2, 29h, 10h, 0C8h
                db 8Ch, 6, 0B1h, 41h, 3, 1, 0ACh, 64h, 46h, 3, 5Ah, 8
                db 84h, 20h, 0CEh, 4, 29h, 8, 0C5h, 5, 1, 0C0h, 0C9h, 2Eh
                db 5, 9, 74h, 30h, 1Fh, 29h, 90h, 1, 4
level_34        db 0Ch, 0Fh, 0F6h, 0DBh, 21h, 82h, 59h, 14h, 88h, 5Ah
                db 21h, 11h, 8, 64h, 40h, 0D1h, 8, 98h, 11h, 6Ch, 84h
                db 10h, 84h, 0B0h, 18h, 0Ch, 8, 42h, 11h, 8, 0D1h, 0Ch
                db 91h, 88h, 0E6h, 30h, 40h, 88h, 6Fh, 10h, 88h, 96h, 0B1h
                db 81h, 0Ah, 63h, 43h, 47h, 0B4h, 80h, 0Ah, 0Ah
level_35        db 14h, 10h, 0F6h, 58h, 35h, 90h, 0D0h, 45h, 35h, 0A1h
                db 92h, 23h, 0A5h, 0E8h, 64h, 22h, 59h, 21h, 15h, 0A5h
                db 10h, 89h, 60h, 32h, 56h, 20h, 84h, 15h, 84h, 42h, 29h
                db 6, 4, 14h, 30h, 1Dh, 2Dh, 6, 0Ah, 44h, 22h, 11h, 0Ch
                db 4, 15h, 24h, 22h, 1Ah, 21h, 0Ah, 5, 1, 10h, 8Eh, 41h
                db 8, 2Ah, 8, 38h, 18h, 10h, 84h, 42h, 8, 38h, 11h, 15h
                db 91h, 40h, 70h, 84h, 42h, 25h, 0Ah, 3, 0A1h, 0A0h, 83h
                db 41h, 0D3h, 11h, 8Eh, 0, 0Ah, 1
level_36        db 12h, 13h, 0B2h, 9Fh, 24h, 96h, 8, 78h, 0A6h, 5, 1, 0E0h
                db 0C8h, 82h, 82h, 9Bh, 8, 52h, 10h, 0A4h, 22h, 0D8h, 0Ch
                db 6, 44h, 8, 31h, 0A5h, 45h, 0Ah, 55h, 31h, 88h, 32h
                db 5Ah, 21h, 13h, 88h, 28h, 88h, 44h, 22h, 18h, 23h, 10h
                db 41h, 0A1h, 59h, 38h, 83h, 25h, 22h, 58h, 23h, 11h, 28h
                db 84h, 18h, 21h, 13h, 8Ch, 10h, 0A1h, 4Ah, 12h, 0C6h
                db 30h, 19h, 21h, 0A0h, 83h, 18h, 88h, 44h, 50h, 0C0h
                db 81h, 14h, 83h, 65h, 40h, 0E0h, 42h, 12h, 0D0h, 70h
                db 32h, 11h, 8Eh, 16h, 0F9h, 20h, 7, 8
level_37        db 15h, 0Fh, 0F6h, 1Fh, 1, 0CDh, 27h, 0B0h, 1Ch, 0D2h
                db 18h, 21h, 90h, 0C0h, 63h, 4Ah, 15h, 0Ah, 0C3h, 1, 9Ch
                db 10h, 40h, 0C1h, 2Ch, 86h, 3, 38h, 0ABh, 68h, 30h, 18h
                db 25h, 0A0h, 0C8h, 54h, 4, 29h, 60h, 30h, 44h, 10h, 50h
                db 28h, 60h, 40h, 0C0h, 60h, 52h, 14h, 60h, 86h, 83h, 4
                db 0A2h, 10h, 60h, 43h, 59h, 0Ch, 8, 21h, 8, 87h, 0C3h
                db 42h, 81h, 40h, 7Ch, 86h, 42h, 0Ch, 87h, 0C1h, 68h, 0B7h
                db 0CBh, 25h, 0F0h, 0, 9, 0Dh
level_38        db 0Eh, 0Fh, 1Eh, 0D8h, 6Bh, 49h, 0Dh, 5, 8Bh, 18h, 10h
                db 86h, 8, 6Bh, 10h, 60h, 84h, 11h, 58h, 0C0h, 60h, 96h
                db 0C2h, 84h, 28h, 4Ah, 25h, 81h, 50h, 41h, 50h, 20h, 82h
                db 30h, 10h, 41h, 81h, 4, 21h, 4, 18h, 25h, 82h, 18h, 8
                db 34h, 42h, 21h, 10h, 83h, 2, 6, 5, 1, 82h, 54h, 14h
                db 92h, 0D0h, 60h, 0B7h, 0Ah, 74h, 0Ah, 3
level_39        db 17h, 12h, 0F2h, 0C9h, 7Ch, 0F0h, 42h, 0D2h, 0F9h, 0C1h
                db 0ACh, 6Ch, 0F6h, 9Ah, 0C6h, 88h, 64h, 86h, 0C8h, 6Bh
                db 63h, 4, 50h, 0C0h, 0A0h, 86h, 0B5h, 10h, 0E1h, 10h
                db 46h, 0Ah, 0C6h, 48h, 60h, 42h, 11h, 10h, 20h, 0D6h
                db 30h, 4Bh, 2, 10h, 85h, 1, 10h, 89h, 60h, 22h, 11h, 68h
                db 97h, 0C2h, 21h, 91h, 40h, 85h, 0A2h, 58h, 8, 21h, 4Bh
                db 1, 16h, 82h, 29h, 6, 45h, 21h, 0D0h, 0E0h, 60h, 40h
                db 0A0h, 82h, 96h, 3, 81h, 13h, 10h, 0A4h, 22h, 9Ch, 0Dh
                db 6, 8, 81h, 0F2h, 0Ch, 64h, 97h, 0CDh, 2Dh, 0F2h, 80h
                db 0Bh, 5
level_40        db 0Bh, 0Bh, 0C2h, 91h, 0ACh, 4, 1Bh, 14h, 4, 19h, 14h
                db 21h, 11h, 0Ah, 33h, 88h, 30h, 10h, 0A7h, 40h, 60h, 20h
                db 0B0h, 62h, 21h, 6, 42h, 0Ah, 4, 15h, 2, 0A0h, 83h, 6
                db 0A2h, 9Ch, 0, 8, 1
level_41        db 14h, 0Fh, 0F2h, 0Bh, 7Ch, 0B2h, 19h, 21h, 0F2h, 48h
                db 6Ch, 3Eh, 41h, 0Ch, 11h, 40h, 7Ch, 10h, 88h, 0A0h, 40h
                db 0F8h, 8, 54h, 20h, 64h, 0A6h, 43h, 24h, 42h, 0D0h, 60h
                db 0E4h, 43h, 41h, 6, 37h, 90h, 4Ch, 8, 2Ch, 46h, 0A2h
                db 19h, 21h, 5, 88h, 0D5h, 81h, 41h, 53h, 0FAh, 30h, 32h
                db 21h, 0EEh, 30h, 28h, 0Fh, 94h, 43h, 4, 0BEh, 59h, 4Ch
                db 0, 11h, 8
level_42        db 0Dh, 12h, 1Ch, 0D8h, 44h, 32h, 53h, 1, 0Ah, 45h, 21h
                db 80h, 0C0h, 82h, 13h, 18h, 8, 88h, 83h, 21h, 10h, 0AAh
                db 14h, 84h, 18h, 14h, 17h, 4Ah, 15h, 20h, 0C9h, 0Ch, 0Ah
                db 0B1h, 92h, 11h, 0Dh, 63h, 10h, 84h, 43h, 5Ah, 49h, 64h
                db 0ACh, 60h, 22h, 10h, 6Bh, 18h, 8Ch, 4, 1Ah, 0C6h, 3
                db 1, 0F0h, 0C1h, 48h, 85h, 4Bh, 61h, 0A0h, 0E9h, 8Ch
                db 80h, 2, 1
level_43        db 11h, 10h, 0A3h, 0D9h, 6Ch, 3Eh, 8, 68h, 30h, 10h, 62h
                db 0Ah, 3, 41h, 40h, 0A3h, 4, 30h, 19h, 21h, 10h, 82h
                db 10h, 22h, 19h, 0Ch, 88h, 15h, 1, 6, 83h, 21h, 0Ah, 42h
                db 0Dh, 10h, 84h, 14h, 90h, 83h, 41h, 80h, 0C1h, 0Ch, 8
                db 1Ah, 0Dh, 10h, 88h, 88h, 23h, 18h, 0A4h, 32h, 10h, 6Bh
                db 18h, 39h, 5, 8Ch, 0E1h, 0Fh, 6, 0B4h, 87h, 83h, 5Ah
                db 43h, 0C7h, 0BCh, 0, 0Fh, 3
level_44        db 19h, 13h, 0C3h, 1Fh, 34h, 0B6h, 43h, 0E6h, 86h, 42h
                db 8, 0B7h, 0C9h, 8, 40h, 0C0h, 0A8h, 0C7h, 8, 54h, 12h
                db 88h, 74h, 34h, 4Bh, 4, 41h, 4, 0Ch, 10h, 0C9h, 8Eh
                db 8Ah, 4Ch, 44h, 32h, 43h, 7, 20h, 0D0h, 41h, 80h, 89h
                db 44h, 0B8h, 52h, 0Ah, 20h, 0C0h, 41h, 12h, 8Ah, 44h
                db 31h, 81h, 91h, 8, 41h, 81h, 40h, 0A0h, 2Ah, 18h, 0C0h
                db 0A8h, 60h, 84h, 18h, 8, 20h, 0D9h, 1Ah, 11h, 8, 40h
                db 8Ah, 64h, 22h, 10h, 63h, 1Ah, 14h, 6, 8Bh, 68h, 31h
                db 88h, 20h, 0C1h, 0Fh, 18h, 0C6h, 32h, 11h, 0Fh, 96h
                db 18h, 0D6h, 0C0h, 7Ch, 0B0h, 0C6h, 0D0h, 0F9h, 64h, 30h
                db 4Bh, 4, 3Eh, 61h, 0ECh, 0, 0Dh, 7
level_45        db 13h, 0Bh, 0E3h, 5Eh, 2Dh, 80h, 0C1h, 4Dh, 86h, 43h
                db 22h, 0A0h, 0C1h, 48h, 31h, 8, 44h, 30h, 11h, 0Eh, 4
                db 18h, 21h, 14h, 0C1h, 28h, 45h, 40h, 0A0h, 50h, 43h
                db 3Ah, 82h, 21h, 80h, 0C9h, 0Ch, 0E3h, 81h, 12h, 89h
                db 67h, 18h, 25h, 81h, 40h, 0A0h, 0F4h, 43h, 21h, 90h
                db 0F8h, 3Dh, 9, 7
level_46        db 16h, 11h, 0A3h, 0D8h, 29h, 0D0h, 0C9h, 0Ch, 14h, 0C0h
                db 74h, 32h, 29h, 0Ch, 0Ah, 3, 0A1h, 80h, 88h, 41h, 0B2h
                db 9Ah, 21h, 0Ah, 44h, 22h, 20h, 0C8h, 68h, 0A6h, 3, 1
                db 8, 29h, 31h, 82h, 9Ah, 25h, 9Dh, 0Ch, 85h, 3, 1, 14h
                db 0DEh, 87h, 3, 1, 4, 43h, 7Bh, 50h, 60h, 2Ah, 49h, 67h
                db 19h, 0Ch, 90h, 82h, 11h, 90h, 0CEh, 30h, 43h, 0A2h
                db 81h, 11h, 68h, 84h, 4Dh, 0Ch, 4, 29h, 0Dh, 86h, 43h
                db 1, 12h, 0C1h, 2Dh, 86h, 45h, 1, 50h, 53h, 0A5h, 0B0h
                db 19h, 0Fh, 96h, 73h, 0E0h, 0Bh, 0Eh
level_47        db 13h, 0Fh, 16h, 0F9h, 61h, 90h, 0F9h, 61h, 4, 63h, 0E1h
                db 0C1h, 0Ch, 68h, 21h, 8, 50h, 96h, 43h, 41h, 14h, 85h
                db 42h, 6, 82h, 2Dh, 6, 2, 86h, 30h, 52h, 21h, 58h, 43h
                db 2, 30h, 28h, 8, 84h, 42h, 21h, 0F0h, 83h, 38h, 8Dh
                db 60h, 96h, 9, 0D0h, 1Bh, 29h, 4, 19h, 0C4h, 1Fh, 1, 12h
                db 82h, 0Fh, 80h, 0E8h, 7Ch, 1Eh, 80h, 9, 3
level_48        db 10h, 0Fh, 0D2h, 9Fh, 24h, 30h, 43h, 0E4h, 6, 48h, 7Ch
                db 4, 44h, 21h, 0D2h, 55h, 2, 10h, 0C9h, 4Dh, 0Ah, 42h
                db 25h, 80h, 8Bh, 60h, 20h, 0D0h, 41h, 0ACh, 81h, 4, 19h
                db 10h, 0ACh, 41h, 6, 4, 8, 2Ch, 0F1h, 88h, 22h, 58h, 29h
                db 12h, 83h, 25h, 30h, 28h, 21h, 50h, 0D9h, 28h, 56h, 1Dh
                db 0Ch, 10h, 0C8h, 74h, 0F4h, 7, 0Bh
level_49        db 13h, 10h, 0C3h, 0D9h, 70h, 86h, 35h, 6, 43h, 64h, 31h
                db 9Ch, 2Ah, 10h, 34h, 43h, 19h, 0D8h, 82h, 0Ah, 10h, 0D0h
                db 63h, 3Bh, 10h, 41h, 0Ah, 2, 29h, 9Ch, 60h, 34h, 10h
                db 41h, 82h, 10h, 7Ch, 4, 18h, 10h, 42h, 58h, 8, 22h, 10h
                db 42h, 91h, 48h, 41h, 90h, 0C1h, 2Ch, 52h, 10h, 41h, 4
                db 1Ah, 0Ch, 8Ah, 42h, 8, 0B6h, 2, 11h, 16h, 0E0h, 60h
                db 2Ah, 43h, 21h, 90h, 0C0h, 60h, 30h, 4Bh, 24h, 36h, 18h
                db 0Ch, 7, 3, 44h, 30h, 53h, 86h, 20h, 2, 7
level_50        db 15h, 10h, 0B3h, 0DAh, 78h, 34h, 4Bh, 41h, 0E0h, 0D8h
                db 82h, 82h, 9Ah, 29h, 6, 44h, 15h, 6, 48h, 42h, 80h, 0AAh
                db 42h, 8, 11h, 2Ch, 84h, 19h, 25h, 81h, 2, 8, 50h, 28h
                db 0Ch, 0Ah, 2, 29h, 4, 42h, 0A9h, 5, 18h, 14h, 14h, 88h
                db 60h, 94h, 10h, 41h, 81h, 41h, 0Dh, 8Ah, 45h, 21h, 8
                db 11h, 8Ch, 6, 8, 60h, 21h, 18h, 0Ch, 6, 70h, 0B5h, 40h
                db 60h, 20h, 0C0h, 77h, 11h, 10h, 28h, 10h, 60h, 3Bh, 8Fh
                db 86h, 3, 0BBh, 58h, 21h, 83h, 0DBh, 29h, 0, 5, 9
level_51        db 10h, 0Eh, 0B4h, 53h, 81h, 9Ch, 41h, 82h, 99h, 0Ch, 0E9h
                db 60h, 50h, 19h, 0Dh, 68h, 42h, 81h, 4Ah, 21h, 0ADh, 0Ch
                db 8Ah, 2, 25h, 9Ch, 21h, 8, 20h, 41h, 10h, 0D0h, 60h
                db 50h, 10h, 60h, 84h, 11h, 28h, 0B4h, 20h, 41h, 50h, 2Ah
                db 21h, 81h, 48h, 0A8h, 50h, 43h, 21h, 8, 44h, 10h, 0A6h
                db 0Ch, 60h, 96h, 2, 21h, 0A2h, 9Ah, 25h, 0F2h, 80h, 5
                db 9
level_52        db 15h, 0Eh, 14h, 0F9h, 0A4h, 30h, 5Bh, 0E4h, 87h, 42h
                db 2Dh, 0C0h, 85h, 2Ch, 12h, 0C8h, 70h, 31h, 8Ch, 8, 83h
                db 1, 7, 3, 18h, 0E1h, 11h, 12h, 0D0h, 59h, 0C8h, 30h
                db 14h, 15h, 18h, 0C6h, 30h, 43h, 64h, 28h, 0C9h, 0Bh
                db 3Ah, 81h, 2, 21h, 81h, 59h, 0Ch, 68h, 60h, 52h, 19h
                db 35h, 67h, 85h, 43h, 25h, 0B6h, 18h, 0D0h, 21h, 6Fh
                db 86h, 3, 21h, 0F2h, 8Eh, 7Ch, 0A0h, 5, 0Ch
level_53        db 0Dh, 13h, 93h, 0D3h, 21h, 82h, 59h, 0Ch, 84h, 29h, 14h
                db 6, 43h, 5, 2Ah, 19h, 21h, 6, 3, 1, 82h, 18h, 0Bh, 3Ch
                db 86h, 3, 4, 31h, 8Ch, 6, 3, 21h, 67h, 22h, 18h, 8, 28h
                db 0C6h, 28h, 18h, 8, 40h, 0C6h, 30h, 18h, 8, 20h, 0C7h
                db 30h, 18h, 8, 40h, 0C6h, 2Ah, 18h, 0Dh, 0Ch, 0E6h, 2
                db 25h, 80h, 0C0h, 60h, 96h, 8Ah, 60h, 86h, 0Dh, 54h, 0A1h
                db 60h, 0A0h, 86h, 8, 64h, 32h, 7Bh, 68h, 4, 7
level_54        db 17h, 14h, 1Eh, 0FBh, 2Ch, 6, 48h, 60h, 32h, 19h, 0Ch
                db 86h, 2, 15h, 8Ah, 45h, 22h, 93h, 50h, 60h, 32h, 4Ah
                db 21h, 54h, 0C8h, 44h, 2Bh, 19h, 0Ch, 90h, 85h, 21h, 19h
                db 8Ch, 84h, 21h, 28h, 30h, 11h, 9Ah, 0D9h, 25h, 1Eh, 0C6h
                db 32h, 11h, 4Fh, 80h, 0C6h, 21h, 48h, 60h, 22h, 11h, 28h
                db 96h, 34h, 20h, 0C1h, 48h, 32h, 19h, 21h, 8Dh, 8, 96h
                db 8, 7Ch, 0Ah, 31h, 0D2h, 10h, 64h, 32h, 43h, 1, 92h
                db 18h, 31h, 1Eh, 0DAh, 25h, 0F0h, 19h, 0Dh, 8, 42h, 14h
                db 4, 20h, 82h, 90h, 83h, 44h, 20h, 0A8h, 42h, 30h, 42h
                db 21h, 0A0h, 88h, 60h, 42h, 21h, 48h, 50h, 20h, 41h, 10h
                db 0F8h, 0Ch, 87h, 0Fh, 7Dh, 0C4h, 4, 0Bh
level_55        db 16h, 0Fh, 1Eh, 0FBh, 6Fh, 9Eh, 8, 68h, 40h, 0E1h, 8
                db 32h, 43h, 6, 22h, 58h, 0Ah, 84h, 52h, 8Ch, 90h, 0A3h
                db 5Ah, 42h, 8, 30h, 1Ah, 10h, 35h, 0A1h, 4, 10h, 42h
                db 4, 10h, 41h, 0ADh, 0Ch, 84h, 10h, 81h, 8Ah, 43h, 5Ah
                db 14h, 41h, 4, 10h, 82h, 85h, 1Ah, 0D0h, 0C8h, 41h, 92h
                db 69h, 0Dh, 63h, 41h, 6, 4, 64h, 23h, 10h, 0A5h, 10h
                db 0C0h, 44h, 0B1h, 40h, 0A4h, 40h, 0C1h, 0Dh, 84h, 28h
                db 10h, 86h, 43h, 25h, 0B2h, 19h, 35h, 0D3h, 0DEh, 0, 5
                db 8
level_56        db 0Eh, 10h, 0F4h, 0D0h, 78h, 0A4h, 11h, 88h, 30h, 4Ah
                db 8, 41h, 5, 2, 10h, 0E8h, 54h, 94h, 0A8h, 22h, 30h, 4Bh
                db 1, 82h, 10h, 42h, 86h, 48h, 51h, 91h, 40h, 68h, 30h
                db 20h, 84h, 0B4h, 10h, 64h, 50h, 1Ah, 8, 86h, 42h, 0Ch
                db 90h, 0C1h, 68h, 32h, 1Fh, 0Ch, 87h, 74h, 0B2h, 1Dh
                db 0C6h, 0CFh, 64h, 0Bh, 7
level_57        db 12h, 0Bh, 0F2h, 9Ch, 3Dh, 82h, 1Ah, 21h, 81h, 60h, 86h
                db 32h, 42h, 21h, 92h, 19h, 0D0h, 83h, 10h, 42h, 22h, 0A1h
                db 9Dh, 8, 3Ah, 19h, 27h, 43h, 2, 22h, 58h, 0A4h, 9Dh
                db 8, 50h, 45h, 2, 10h, 0D6h, 0A5h, 69h, 0ACh, 6, 0Dh
                db 78h, 0A7h, 0C9h, 0, 7, 5
level_58        db 1Bh, 14h, 0F2h, 0CCh, 7Ch, 0E2h, 0DAh, 0Fh, 9Ch, 18h
                db 21h, 6, 0Bh, 7Ch, 0A0h, 0C8h, 0ECh, 63h, 19h, 0Dh, 16h
                db 8Ah, 42h, 2Ch, 67h, 50h, 68h, 32h, 4Bh, 4, 20h, 0BDh
                db 68h, 44h, 34h, 10h, 0B0h, 84h, 18h, 0C6h, 34h, 20h
                db 0D1h, 88h, 32h, 10h, 5Dh, 0ADh, 6, 83h, 21h, 8, 0A2h
                db 8, 31h, 0ADh, 6, 82h, 14h, 0Ah, 0C2h, 0Bh, 0B5h, 4
                db 1Ah, 21h, 10h, 0C0h, 84h, 0A0h, 0C1h, 0Ch, 4, 1Bh, 0Ch
                db 0Ah, 4, 25h, 16h, 88h, 41h, 0B2h, 55h, 2Ah, 96h, 0Ah
                db 44h, 20h, 0D1h, 48h, 3Eh, 4Bh, 1, 6, 83h, 2, 6, 5, 4Ch
                db 12h, 0C4h, 46h, 38h, 20h, 41h, 82h, 98h, 0Ah, 32h, 5Ah
                db 0Ch, 8, 83h, 0E5h, 86h, 43h, 2, 80h, 88h, 60h, 86h
                db 0Eh, 64h, 86h, 9, 60h, 0E7h, 0C8h, 29h, 0F3h, 0C0h
                db 15h, 0Eh
level_59        db 1Dh, 14h, 0F2h, 9Fh, 3Ch, 0D0h, 0C0h, 7Ch, 0F3h, 43h
                db 7, 3Eh, 49h, 0ACh, 7, 3, 0E4h, 86h, 42h, 8, 20h, 83h
                db 24h, 3Eh, 40h, 42h, 0B1h, 41h, 0Ch, 8, 1Fh, 4, 0A1h
                db 10h, 60h, 20h, 0D9h, 0ECh, 6, 5, 1, 81h, 10h, 44h, 40h
                db 0C8h, 41h, 80h, 88h, 41h, 90h, 0D9h, 2Dh, 8, 10h, 60h
                db 20h, 0C0h, 54h, 84h, 4Bh, 1, 80h, 88h, 88h, 30h, 10h
                db 68h, 50h, 85h, 1, 92h, 10h, 0A0h, 20h, 8Ch, 50h, 40h
                db 0D1h, 0Ch, 6, 45h, 44h, 68h, 60h, 34h, 4Ah, 8, 41h
                db 9, 60h, 95h, 9Eh, 1Bh, 21h, 82h, 2Ah, 15h, 90h, 0D6h
                db 86h, 8, 60h, 86h, 45h, 1, 46h, 8, 6Bh, 3Bh, 4Ah, 0Ch
                db 0Ah, 2, 8, 50h, 0C1h, 0Dh, 67h, 6Bh, 44h, 30h, 28h
                db 8, 40h, 0C0h, 6Bh, 3Bh, 4Bh, 1, 0A1h, 0Ah, 64h, 22h
                db 0B3h, 0B4h, 0B4h, 19h, 0Ch, 6, 3, 1, 82h, 33h, 0B4h
                db 0B8h, 73h, 7, 0B0h, 0F0h, 0Dh, 0Dh
level_60        db 1Ah, 10h, 0E2h, 0DFh, 3Ch, 90h, 0C9h, 4Fh, 9Eh, 10h
                db 0A8h, 0A6h, 0Ah, 7Ch, 32h, 10h, 8Ch, 14h, 0C0h, 47h
                db 0B0h, 83h, 22h, 90h, 0C8h, 41h, 8Dh, 61h, 0Ah, 0Ah
                db 41h, 80h, 0C0h, 41h, 8Ch, 0A0h, 32h, 28h, 0Ch, 8, 10h
                db 83h, 42h, 0Bh, 39h, 4, 20h, 84h, 30h, 43h, 41h, 63h
                db 1, 8Ch, 54h, 86h, 48h, 68h, 88h, 16h, 30h, 18h, 0C4h
                db 20h, 0A0h, 41h, 8, 64h, 84h, 31h, 80h, 0B3h, 0C4h, 8
                db 86h, 44h, 0Ah, 21h, 2, 0C6h, 3, 18h, 0E1h, 0Ch, 86h
                db 0C2h, 0C6h, 3, 1Bh, 58h, 25h, 18h, 0B4h, 20h, 88h, 0BCh
                db 0F1h, 0DAh, 58h, 3Dh, 0F6h, 8, 0D6h, 0F9h, 0A6h, 20h
                db 6, 8
barrel_count    db 0
current_barrel  dw 0
barrels:
