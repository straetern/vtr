;32n1e: buf2.asm = buffer routines;
;"buffer" = "table", here;
;memory for buffers is declared at assembly-time,
;but buffers are 'set up' in the prog;
;gen reg-use: ax for data; bx for buf-no or buf-size; cx f total no. of bufs in countg, or buf-width;
;j4a: ignful;
;needs: strg.asm, io2.asm;
;n1e: take bx as buf-no: set-up time the same (as f bl) i callg prg & saves the bh-to-0-settg; -also: bufn now a word;
;-remem to set up bufn externally (to 0) Before executg setbuf!
;-----------------------------------------------------------------------------------

maxnbufs equ 10 ;max no of buffers

data segment
 
 ignful db ? ;when 1, wrtbuf ignores full-state & ceases writing;
 bufn dw ? ;total number of buffers set up - also pts to next free buf-no;
 
badrs: dw maxnbufs dup (?) ;start adrs of bufs
bptrs: dw maxnbufs dup (?) ;local ptrs into bufs
bwids: db maxnbufs dup (?) ;widths of buffers (: 1 or 2 bytes)
bsizs: dw maxnbufs dup (?) ;sizes of bufs: no.of bytes!(not cells);

data ends

;------------------------------------------------------------------

setbuf:
;sets up buffer, buffer no is incd at end;
;> ax: start adr
;> bx: buf-size
;> cl: width of buffer (1 or 2 (bytes))
;~ dx
;< dl: bufn assigned

 mov dx, bufn ;setup f wd-mov into si 
 mov si, dx
 mov [bwids+si], cl
 sal si, 1 ;si*2
 mov [badrs+si], ax
 mov [bsizs+si], bx
 inc bufn ;ready f next buffer
 ret


rstbufs:
;resets all buf-ptrs
;assumes bufn>0!

 mov cx, bufn
 mov si, 0
nxtbptr:
 mov w[bptrs+si], 0
 add si, 2
 loop nxtbptr
 ret
 

rstbuf:
;reset buf-ptr
;> bx=bufn
;~ si only

 mov si, bx
 sal si, 1 ;*2
 mov w[bptrs+si], 0
 ret


getptr:
;> si: buf-no;
;< di: ptr(bx);

 sal si, 1
 mov di, w[bptrs+si]
 ret


wrtbuf:
;write buffer
;> al/ax: data;
;> bx: buffer-no;
;< C set iff buf full;
;>ignful: non-zero = dont erxit on full;
;- all Rs;

 pusha
 mov si, bx
 mov ch, 0 ;setup f cx
 mov cl, b[bwids+si]
 sal si, 1 ;*2
 mov bx, w[badrs+si] ;set up base adr
 mov di, w[bptrs+si] ;set up index

;check wh the cx values still fit in
 add di, cx 
 cmp di, [bsizs+si]
 jae bufful
 sub di, cx ;reset di to old value

;write the 1 or 2 bytes
 mov b[bx+di], al ;write lo-byte to buffer
 cmp cl, 1 ;width=1?
 je buf1
 mov b[bx+di+1], ah ;wrt hibyte
buf1:
 add w[bptrs+si], cx ;update ptr (C must be clear after, since no overflow)
r8:
 popa
 ret

bufful:
 mov w[bptrs+si], 2 ;reset ptrs if contg (but not to 0 to indicate: some data there;
 mov al, ignful
 sar al, 1 ;set C by shift!
 jc r8
 mov ax, '0'
 sar si, 1 ; div by 2 ag
 add ax, si ;outp buf-no!
 add sp, 16 ;clear pushed regs (pusha)
 jmp erxit
 

ptrtobuf:
;copies a buffer-ptr into another buffer
;al: buf-no of buf-ptr 
;bl: no of dest buffer
;assumes dest buf is large enough to take relevant ptr-part (ie: if ptr needs its whole 2 bytes, dest-buf must be of width 2!)

 mov si, ax
 sal si, 1
 mov ax, w[bptrs+si]
 jmp wrtbuf ;uses bl as buf-no


ptrcntcmp:
;compares ptr of ax to last content of bx (width 2 assumed, since ptrs alw 2 bytes);
;-> ('cnt' is interpreted as a ptr into buf al;)
;>ax: buf of ptr
;>bx: buf of last cnt;
;4 poss exits:
; Z1C0: ptr(al)=0, -exits with this Before Z1C1 (if both the z1c0- & z1c1-conds are satisfied)
; Z1C1: no last content (ptr(bl)=0),
; Z0Cx: outcome of compare: C1: cnt<ptr(al);
;(< ax=ptr(al); if Z0: dx=cnt;)

 mov si, ax
 sal si, 1
 mov ax, w[bptrs+si] ;get ptr of buf al
 cmp ax, 0
 jz ret ;Z1C0
 mov si, bx
 sal si, 1
 mov bx, w[bptrs+si]
 sub bx, 2 ;point to last content (assume width 2 f buf bl)
 jae cntok
 mov bl, 1
 dec bl ;set Z w/o resettg C
 ret ;Z1C1
cntok: 
 mov di, bx
 mov bx, w[badrs+si] ;set base
 mov dx, w[bx+di] ;get last content 'cnt'
 cmp dx, ax
 inc si ;to clr Z w/o affectg C (si is even fr sal above!)
 ret ;Z0Cx


srchbuf:
;n1a: search f string (si) in buffer (bl), startg fr di;
;look only in written portion (assume seq writg)
;assume: width=1
; also assume: buf Not empty!;
;>si: bufn
;>ax: string to be srchd
;>di: local srch start
;>cx: length of strg
;<C1 iff not fd in buf;
;<di: buf-local ptr to found occurc
;~ ax, si, di;
;- cx;

 push ax ;save strg-start

 mov ax, di
 sal si, 1
 mov di, w[badrs+si] ;get start of buf
 mov fx, di
 add di, ax ;calc absol start
 
 mov dx, fx ;calc end-pt of buf
 add dx, [bptrs+si] ;get end-pt of buf (pos of last val written, +1)
 dec dx ;pt to Last loc
  
 pop si ;absol strg-start
 call fnds
 jc ret ;not fd
 sub di, fx ;return Local ptr, subtr buf-start; result must be >=0, so C0;
 ret


srchmonb:
;search monotonic buffer, ie. thro a list of monotonically rising vals, usu ptrs;
;assume buf is width 2, buf filled with vals & its ptr set to one after last val, as usu;
;>si: bufn
;>ax: word-val to be srchd
;<di: local ptr-pos at which val is found, or pos of 1st val grtr than given val -givg 2* n of vals Below srch-val;
;<dx: total no.of vals in buf *2 (& end-adr +1) -givg 2* n of vals Above (or equal to) srch-val; -if dx=0, buf is empty;
;<C1 iff buf empty;
;<Z1&C0: equality-match;
;-ax; ~bx;

 call getptr ;get end-pt of buf, bufn in si given
 mov dx, di
 cmp dx, 1 ;chk f buf empty
 jc ret
 mov bx, w[badrs+si] ;get base adr of monbuf
 mov di, -2 ;init monbuf-ptr
cmpnxt1:
 add di, 2
 cmp di, dx
 je endbuf2
 cmp w[bx+di], ax
 je ret
 jc cmpnxt1
endbuf2:
 mov bl, 0
 inc bl ;clr Z
 ret ;C0

bfnam: db ?, 0 ;buf filnam
bdnam: db '\a\bufsvs', 0 ;buf dirnam

svbufs:
;save all bufs in dir \a\bufsvs
;[[>al: a sgl chr used as the file-name!
;o2ae: >ax: asciz-adr;
;-> also save the bptr at beginng of each buf;

; mov b[bfnam], al

; mov dx, bdnam
; call sdir

 stc ;w create
 call fop0 ;create & open
 mov ex, ax ;save file-handle
 mov fx, bufn ;calc si-end-val
 sal fx, 1
 mov si, 0
nxtbuf:
;save ptr
 mov ax, ex
 mov cx, 2
 mov dx, bptrs
 add dx, si
 call fop1

;save buf
 mov ax, ex
 mov cx, w[bsizs+si]
 mov dx, w[badrs+si]
 stc ;write
 call fop1

 add si, 2
 cmp si, fx
 jne nxtbuf
alldone2:
 mov ax, ex
 call fop2

; call rdir
 ret


ldbufs:
;load all bufs fr dir \a\bufsvs
;>al: sgl-char file-name

 mov b[bfnam], al

 mov dx, bdnam
 call sdir

 mov ax, bfnam
 clc ;w/o create
 call fop0 ;open only
 mov ex, ax ;save file-handle

 mov fx, bufn
 sal fx, 1
 mov si, 0
nxtbuf2:
 mov ax, ex
 mov cx, w[bsizs+si]
 mov dx, w[badrs+si]
 clc ;read
 call fop1
 add si, 2
 cmp si, fx
 jne nxtbuf2
 
alldone3:
 mov ax, ex
 call fop2

 call rdir
 ret


 















