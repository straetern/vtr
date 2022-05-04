;32m7u': strgs.asm = string handlg routines
;-------------------------------------------

fnds:
;find string in given region
;-only chks wheth beginng of srch-srtg still within srch-region
;
;>si: pos of strg to be srchd
;>cx: length of srch-strg
;>di: pos fr which to be srchd
;>dx: end adr (last loc) of srch-region;
;
;<C1 [or: Z0] iff not found within region;
;[<Z1 iff found;]
;<di: pos at wh strg is found
;-:si, cx & dx: for continued srchg (only need to incr di);
;(<bx: end adr of srch-regn
;~ax

 mov es, ds
 dec di ;pre-dec, f init inc-di
 mov ax, 0
nxtloc:
 sub si, ax ;restore str-start & srch-loc
 sub di, ax
 inc di ;next loc
 cmp dx, di
 jc ret
 add cx, ax ;restore orig len
 mov ax, 0
nxtstrbyt:
 inc ax
 cmpsb
 loope nxtstrbyt
 jne nxtloc ;if last chrs didnt match up (if it was the last one or not), cont srch;
;C=0 & last chr matched
 sub si, ax ;restore str-start & srch-loc
 sub di, ax
 mov cx, ax ;restore len f poss contd srchs
 ret


cops:
;copy string
;>si: pos of strg to be copied
;>cx: len
;>di: destin

 mov es, ds
nxtbyt1:
 movsb
 loop nxtbyt1
 ret


cops0:
;n3: copy 0-terminated string
;if zero-string, the sgl 0-terminator is still copied;
;>si: string-adr
;>di: dest
;~si, di

 mov es, ds
nxtbyt3:
 movsb
 cmp b[si-1], 0
 jne nxtbyt3
 ret


nrmstrg:
;normalise string at bx, ie: replace all ctrl-chars by ?-signs;
;>bx: string-loc,
;>si: len;
;~di;

 mov di, -1
nxtchr1:
 inc di
 cmp di, si
 je ret
 mov al, b[bx+di]
 cmp al, 020 ;ctrl-char-limit
 jae nxtchr1
 mov b[bx+di], '?'
 jmp  nxtchr1


