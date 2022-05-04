;32o1a: io4 = io-routines;
;now with mouse-drivers; & vid-setups;
;add: kb-intr-handler & dos-edit-inp;
;-------------------------------------------

;----------video------------------------

inigrvid:
;init graphics-scrn

 mov ax, 00013 ;Set video mode (320x200x256)->64000 posns: adr<2 bytes!;
 int 010    ;Interrupt: Video
 ret


initxvid:
;init txt-scrn

 ret


;------ mouse routines -------------

data segment

mbuts db ?

data ends

getbtn:
;<al: buttons pressed: b0=left, b1=right, other bits are zero!;
;i5u: mbuts < last button-state read (al);
;< Z=1 iff no butn pr;
;< C=1 iff rt butn pr (either with or w/o left butn!)
;~ bh [= bh changed & undefd], (< bl=2)

 mov ax, 5
 mov bx, 0
 int 033
 and al, 03 ;never trust the OS! (other bits might be set, confuses checkg)
 mov mbuts, al
 jz ret ;al=0: Z=1, C not defd
 mov bl, 1 ;init reverse compare (f elegance!)
 cmp bl, al
 jb ret ;al=2,3: C=1 & Z=0
 inc bl ;al=1: C=0, clear Z
 ret 


wtbtn:
;k3i: wait f a button to be prd

 call getbtn
 jz wtbtn
 ret

wtbtnrel:
;o2e: wait f all butns to be released

 call getbtn
 cmp al, 0
 jnz wtbtnrel
 ret


;-------old (32U5a)----------------------

exit:
 mov ax, 04C00
 int 021


rstvid:
;i5u: needed to 'normalise' video after graphics mode (from vp3)
 mov ax, 03 ;Set video mode (80x25x16)
 int 010   ;Interrupt: Video
 ret


erxit: 
;i7i: error-exit: rst vid & prt out error message (a sgl chr!)
;> al: chr to be outp

 cmp outon b, 0
 je noout2
 push ax
 call rstvid
 pop ax
noout2:
 call wrt

 mov ax, svlog
 call fop2 ;close svlog-file
 jnc closok
 mov ax, 'C' ;close-error
 call wrt
closok:

 pop ax ;pop return adr of sub fr which erxit-jmp occurred
 stc
 mov bx, obuf
 mov si, 0
 call hxaso
 mov cl, 4
 call outp

 ;call io1

 jmp exit


rd:
;wait for char
;ret chr in al
 mov ah, 01
 int 021
 ret 


wrt:
;write chr in al
 mov dl, al
 mov ah, 02
 int 021
 ret


rdd:
;read directly: dont wait; 
;zf set, al=0 if no char avail
;zf clr -> al = char
 mov ah, 06
 mov dl, 0ff
 int 021
 ret


;----------------------------------------
;32f3ae: buffered input & string output

ibufl equ 100
obufl equ 100

data segment
 ibuf: db ibufl dup (?)
 obuf: db obufl dup (?)
data ends


inp:
;32f3ae, u & f4i;
;rd chars until Return;
;strg returned in ibuf;
;no terminatn chr, but length retd in bl;
;<bl: length;
;<si: loc foll;
;add 32o1i: allow bkspcs;

 mov si, ibuf
 mov bl, 0
nxtchr: 
 cmp si, (ibuf + ibufl) ;end of ibuf reached?
 jne notend1
ret2:
 ret
notend1: 
 call rd
 cmp al, 0d ;end of line?
 je ret2
 cmp al, 8 ;bkspc
 jne notbsp
 dec si
 dec bl
 mov al, ' '
 call wrt
 mov al, 8
 call wrt
 jmp notend1
notbsp:
 mov [si], al
 inc bl ;acknowledge curr chr (in length-value)
 inc si ;move to next chr
 jmp nxtchr


outp:
;32f4i
;write string in outp-buffer given at bx, up to length given in cl (tested first f neg),
; or 0-chr, or obufl-length; 
;with init linefeed;
;si left on next chr, or first ext loc;
;
;>bx: obuf-ptr;
;>cl: len of strg to be prtd out;
;<si: pts to foll loc;

 mov al, 0d
 call wrt
 mov al, 0a
 call wrt
 mov si, 0
nxtchr2:
 dec cl
 js ret1 ;length decremented to (below) zero;
 mov al, [bx+si]
 cmp dl, 0
 je ret1
 call wrt
 inc si
 cmp si, obufl
 jne nxtchr2
ret1:
 ret


cp:
;32f4i: copy one mem-pt to another
;si=src-start; di=trgt-start; cx=length;
 
 cld
 rep movsb
 ret

;----------------------------------------------
;32f4a: hex io;

ashxi:
;32f4u: ashx for a word;
;inp 2 or 4 chrs in ibuf (given, at bx) (in normal inp-order), ptd to by si;
; stops if the 3rd chr is a space-chr;
;outp in ax;
;usg dx as temp;
;leaves si at foll pos;
; -in case of error: leaves si at lonyb(=2nd chr)-pos of chr-pair with error;

 mov ah, [bx+si]
 inc si
 mov al, [bx+si]
 call ashx
 jc err1
 inc si
 mov dl, [bx+si]
 cmp dl, ' '
 jne nxt2
 mov ah, 0
 ret
nxt2:
 mov dh, al
 mov ah, dl
 inc si
 mov al, [bx+si]
 call ashx
 jc err1
 inc si ;to pt at foll pos;
 mov ah, dh
err1: ;for c=1!;
 ret ;c=0 alr;


ashx:
;32f4u: as-to-hx for 1 byte in ax;
;inp 2 chrs in ax, same chr-order as nyb-order in number;
;outp val in al;
;usg dl as temp save;

 call ashx1 
 jc err
 mov dl, al
 mov al, ah
 call ashx1
 jc err
 mov cl, 4
 sal al, cl
 or al, dl
 clc
err: ;c set alr when comg fr 'jc'!;
 ret 


ashx1:
;1 chr in al -> 1 hex-nyb;
; C set if chr out-of-range, clr otherw;
  
 sub al, '0' ;after subtr, vals 0-9 are alr finished;
 jb outrg
 cmp al, 9 
 jbe fin1
 and al, 0df ;chg poss small letters to cap letters
 sub al, ('A'-'0'-10) ;subtr, so that 'A' gives 10dec;
 cmp al, 10
 jb outrg
 cmp al, 0f
 ja outrg
fin1:
 clc ;no error
 ret
outrg:
 stc ;out-of-rge
 ret
 
;32f5o: hxas;

hxas1:
; 1 nyb (lonyb of al) to 1 chr (ax);
;(errors no poss!);

 cmp al, 9
 ja lett
 add al, '0'
 ret
lett:
 add al, ('A'-10)
 ret


hxas:
;1 byte (al) to 2 chrs (ax)
;usg dl as temp & cl as shift-ctr;

 mov dl, al
 mov cl, 4
 shr al, cl
 call hxas1
 mov ah, al
 mov al, dl
 and al, 0f
 call hxas1
 ret


hxaso:
;32f6i: outp 2 or 4 chrs to obuf (given, at bx) at si-pos;
;>bx: outp-buf-adr;
;>si: curr pos in obuf(bx);
;>ax: byte/word value to be convd
;>C: 0=byte, 1=word
;leaves si at foll loc;
;-bx,~dh;

 jnc sglbyt
 mov dh, al
 mov al, ah
 call sglbyt
 mov al, dh
 jmp sglbyt

sglbyt:
 call hxas
 mov [bx+si], ah
 inc si
 mov [bx+si], al
 inc si
 ret


appdo:
;append a val (al) to outp-buffer, given at bx, at curr si-pos
;>bx: outp-buf-adr
;>al: byte to be appended
;(<si incd
;-bx;

 mov [bx+si], al
 inc si
 ret


;------------------------

mvcrsr:
;32o4i: move txt-cursor in gr-mode
;>dx=pos: dh=row, dl=col;

 mov bh, 0
 mov ah, 02
 int 010
 ret




 

 
 

 



