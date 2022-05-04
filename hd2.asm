;32m7a-u: hd.asm = hd-drivers;
;save & load a whole file (keepg file-handle internal)
;f0, f1 & f2: for operating on an opened file, file-handle externalised
;-all routs use: ax for the file/dir-name, to be created/loaded/saved;
;---------------------------------------------------------------------

mkdir:
;create dir & move into it
;>ax: asciz dir-name

 mov ex, ax
 mov dx, ax
 mov ah, 039 ;create subdir
 int 021
 jc ferr2

 mov dx, ex
 mov ah, 03b ;set curr dir
 int 021
 jc ferr2
 ret

ferr2:
 jmp ferr


ldfil:
;load file fr curr dir
;>ax: asciz-name
;>cx: no of bytes to read
;>dx: destin

 mov ex, cx
 mov fx, dx
 mov dx, ax
 mov al, 2 ;access-mode: read/write;
 mov ah, 03d ;open file
 int 021
 jc ferr
 mov gx, ax ;file handle

 mov bx, ax ;set file handle
 mov cx, ex
 mov dx, fx
 mov ah, 03f ;read file
 int 021
 jc ferr

 mov bx, gx
 mov ah, 03e ;close file
 int 021
 jc ferr
 ret

ferr:
 mov bx, '0' ;prt out err-code in ax
 add bx, ax
 mov ax, bx
 jmp erxit


svfil:
;save file in curr dir
;>ax: asciz-name
;>cx: length in bytes
;>dx: start adr
;>C1: creates .bin-fmt, with init 2-byt start-adr;
;>bx: load-adr, f bin-fmt;
;i'm once ag not trustg the OS here: savg everythg (exc fhdl at one pt);

 mov ex, cx
 mov fx, dx
 mov hx w, 0 ;use as flag f bin-fmt
 jnc notbin

 mov hx, bx ;(bx is non-zero)
 mov si, ax
 mov di, fnbuf
 call cops0 ;copy given asciz-filename into buf
 dec di ;skip end-0
 mov si, bin0
 call cops0 ;append '.bin'&0;
 mov ax, fnbuf ;set up file-name start
notbin:

 mov cx, 0 ;attribs: none set
 mov dx, ax
 mov ah, 03c ;create file
 int 021
 jc ferr

 mov bx, ax ;set file-handle

 cmp hx, 0 ;not bin-fmt?
 je nrmlsav

 mov w[fnbuf], hx ;set up load-adr f save
 mov cx, 2
 mov dx, fnbuf
 mov ah, 040 ;save it
 int 021
 jc ferr

nrmlsav:
 mov cx, ex
 mov dx, fx
 mov ah, 040 ;write to file
 int 021
 jc ferr

 mov ah, 03e ;close file
 int 021
 jc ferr

 ret

fnbuf: db 30 dup ?; file-name buffer, f operats on the name;
bin0: db '.bin', 0


fop0:
;fop=file-operats
;create & open file in curr dir
;>ax: asciz-name
;>C: 0=no create, 1=create;
;<ax: assigned file-handle
;~ex;

 mov ex, ax
 jnc nocreat

 mov cx, 0 ;attribs: none set
 mov dx, ax
 mov ah, 03c ;create file
 int 021
 jc ferr3
 
nocreat:
 mov al, 2 ;access-mode: read/write;
 mov dx, ex
 mov ah, 03d ;open file, returns file-handle;
 int 021
 jc ferr3
 ret

ferr3:
 jmp ferr


fop1: 
;add to file
;>ax: file-handle
;>cx: length of data
;>dx: start-adr
;>C: 0=read, 1=write;
;~bx;

 mov bx, ax ;set file-handle
 jc wrtfil

 mov ah, 03f ;read fr file
 int 021
 jc ferr3
 ret

wrtfil:
 mov ah, 040 ;write to file
 int 021
 jc ferr3
 ret 


fop2:
;close file
;no error check in here, but in erxit (only exit used fr vp-prg)
;>ax: file-handle

 mov bx, ax
 mov ah, 03e ;close file
 int 021
 ret


ferr4: jmp ferr

sdir:
;32n5o: set given dir
;-saves orig dir
;>dx: asciz dir-path to be set

 push dx
 mov dl, 0 ;drv num: default;
 mov si, orgdir+1
 mov ah, 047 ;read curr dir
 int 021
 pop dx
 jc ferr4

 mov ah, 03b
 int 021 ;set new dir
 jc ferr4
 ret

orgdir: db '\', (70 dup (?)) ;original dir-path


rdir:
;32n5o: restore orig dir

 mov dx, orgdir
 mov ah, 03b
 int 021
 jc ferr4
 ret





;-----------------------
;include io2.asm
