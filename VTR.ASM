;32p1a: vtr 0.1a: vtr.asm = vic-tape-reader (for PC)
;-----------------------------------------
;error-exits (subs-specific excluded): 
;
; 'A' = aborted;
; 'F' = file error
; 'C' = file-close error
;------------------------------------------------------------------------------

syncwt equ 30 ;no.of sync-cycles before sync is accepted;

lovl equ 10 ;low-volume acceptance-boundary in sig1 & 4;

lovlwt equ 20 ;no of half-cycles waited until vol accd as too low;
hivlwt equ 20 ;no of consec hcycs waited until vol accd as too high (durg 2-phase: sync);

;min & max volume safety-bounds of swings (ie.pk-to-pk) (f 8-bit samplg)
;(gives warning only)
lovlbd equ 10 
hivlbd equ 110

dtbfs equ 49000 ;assume max poss 24k*2=48k; (longer tho f expanded!?);

prerts equ 6000 ;theor poss: 48k*2!
rserts equ 6000


data segment

;variables:

 sig db ? ;curr signal-type: 0=no signal (noise), 1=chkg f sync, 2=in sync, 3=in data, 4=within error-part, or at end of sig3-phase; 

 cv db ? ;current adc-value read
 lv db ? ;last val rd
 vconst db ? ; =1 at beg of nxtsmpl-loop, when 2nd last v = last v;
 ltp db ? ;last turng pt value

 sld db ? ;sign of last d: 0=pos, 1=neg;

 tpd db ? ;current tp-diff
 stpd db ? ;sign of curr tpd
 ltpd db ? ;last diffr betw tps (tpd= the pk-to-pk val, a measure of the amplitude!)
 l2tpd db ?;2nd last tpd (ie. a full period ,=2 half-cycs, back), used for bit-identificatn;

 wtsy db ? ;wait-ctr f acceptance of sync-phase(sig2);
 wtlv db ? ;wait-ctr f too-low signal
 wthv dw ? ;wait-ctr f too-high;

 bitpt db ? ;bit-part: 0=1st, 1=2nd;
 bitn db ? ;bit-no in byte: 0=byte not started yet; 1=start-bit; 2-9: b0-7; 10=end-bit: parity-chk;
 byt db ? ;data-byte
 
 blkend dw ? ;flags end-of-block to data-readg rout; pts to end of data (+1) after read;
 syncct db ? ;sync-ctr: counts no of sync-cycles, up to start-bit

;buffers:
tapdat0: db dtbfs dup (?) ;for data, bn=0
tapdat dw ?; handle-no to buffer

;tables:
parerrt: db prerts dup (?) ;word-table for parity-error ptrs, bn=1
parerr dw ?;
rsterrt: db rserts dup (?) ;word-table for reset-error ptrs, bn=2
rsterr dw ?;

fnam: db 16 dup (?) ;file name
 fstrt dw ? ;file-start in vic-mem, extracted fr hdr
 flen dw ? ;file-length extracted fr hdr

 svlog dw ? ;file-handle of the save-log
 fnum db ? ;curr file-no;
 hdrok db ? ;hdr-ok-status: 0=not ok, 1=ok;
 datok db ? ;data-ok-status: 0=no blks ok, 1=1st, 2=2nd, 3=both ok;
 cdpos dw ? ;count-dn-posn within retrieved data, markg start of 2nd block;
 flen2 dw ? ;size of file-data found
 svstrt dw ? ;start adr, fr wh to be saved (len in flen2)
 blkid db ? ;block-id: 1=normal hdr, 4=data-hdr, 0=dont know;
 savon db ? ;non-zero enables saving (default)
 blkend1 dw ? ;in-between-blks blkend-save
 invt db ? ;invert signal if 1;

data ends

;----------main--------------------------------------------

main:

 call rdargs

 call setbufs

 call strttap

 call pxer0

 mov fnum, 0
 mov sig, 0
 mov lv, 0 ;lv copied to ltp at 1st pt;
 mov ltpd, 1 ;to avoid div by 0 at beg!
 mov l2tpd, 1 ;same;
 mov wtlv, 0
 mov wthv, 0
 mov wtsy, 0 
 mov syncct, 0
 mov bitpt, 0
 mov mbuts b, 0

nxtfil:
 inc fnum ;start w 1;

rdhdr:
 call rstbufs
 call fndrdblk
 call fndrdblk

rtrhdr1:
 call rtrhdr ;retrieve hdr-data

;chk wheth it's a header
 cmp hdrok, 1
 jne prtfnam1 ;if corrpt, assume it's a hdr

 mov si, w[badrs]
 add si, 9
 cmp b[si], 01 ;prg-hdr
 je prtfnam1
 cmp b[si], 04 ;seq-hdr
 je prtfnam1
 cmp b[si], 03 ;??-hdr (char-set?)
 je prtfnam1

;hdr lost
 mov b[fnam], '*'
 mov b[fnam+1], ' '
 mov hdrok, 1
 mov fstrt, 01001
 mov blkid, 0 ;dont know type
 jmp rtrfil1

prtfnam1:
 call prtfnam

rddata:
 call rstbufs
 call fndrdblk
 call fndrdblk

rtrfil1:
 call rtrfil ;retrieve file-data

;tests to see wheth data-blk is in fact a header
 mov al, datok
 and al, 1 ;chk 1st blk only f now (only 1st hdr-blk chkd anyway)
 jz savfil1 ;if corrpt, assume it's data (for seq or prg)

 cmp blkid, 4
 jne notseq1
 mov si, w[badrs]
 add si, 9
 cmp b[si], 2 ;chk f data-blk
 jne rtrhdr2
notseq1:
 mov si, w[badrs]
 add si, 9
 cmp w[si], 0101
 jne savfil1
 add si, 2
 cmp b[si], 010
 jne savfil1
rtrhdr2:
 jmp rtrhdr1

savfil1:
 call savfil ;update log & save file to hd

 cmp blkid, 4 ;chk hdr f data (seq)-type
 jne notseq2
 inc fnum
 jmp rddata

notseq2:
 jmp nxtfil ;only exits thro user-brk

;-----------------subs-----------------------------

rdargs:
;read arguments

 mov outon b, 1 ;gr on by default
 mov savon, 0 ;save off by default
 mov invt, 0 ;signal non-inverted

 cmp b[081], 0d ;no optns given, exit
 je ret
 cmp b[082], 0d ;freak spc at 081
 je ret 

setouton:
 mov al, b[082]
 sub al, '0'
 cmp al, 2
 jae nochg2
 mov outon b, al
nochg2:
 cmp b[083], 0d
 je ret
 cmp b[084], 0d
 je ret

setsavon:
 mov al, b[084]
 sub al, '0'
 cmp al, 2
 jae nochg3
 mov savon, al
nochg3:
 cmp b[085], 0d
 je ret
 cmp b[086], 0d
 je ret

setinvt:
 mov al, b[086]
 cmp al, '-'
 jne nochg4
 mov invt, 1
nochg4:
 mov b[086], 0
 ret


setbufs:
;setup buffers
 mov ignful b, 1 ;ignore full-bufs (shouldnt happen! -if it does, dont stop);
 mov bufn w, 0 ;reset nxt-free-buf-no;

 mov ax, tapdat0
 mov bx, dtbfs
 mov cl, 1
 call setbuf ;data buffer;
 mov tapdat, dx

 mov ax, parerrt
 mov bx, prerts
 mov cl, 2
 call setbuf ;par-error table;
 mov parerr, dx

 mov ax, rsterrt
 mov bx, rserts
 mov cl, 2
 call setbuf ;reset error table;
 mov rsterr, dx

 call rstbufs ;resets all ptrs
 ret


strttap:
;query for tape-name, create dir w it, & create/open svlog;
 cmp savon, 0
 je ret
 mov bx, messg1
 mov cl, 07f
 call outp
 call inp
 mov [si] b, 0 ;zero-terminate string
 mov ax, ibuf
 call mkdir
 mov ax, idxfiln
 stc
 call fop0 ;create & open svlog
 mov svlog, ax
 mov bx, messg2
 mov cl, 07f
 call outp
 ret

messg1:
db 'Input tape name:', 0

idxfiln:
db 'svlog.txt'
db 0

messg2:
db 'Start tape!'
db 0


fndrdblk:
;find (via sync) & read next block of data
;sig-states: 0-no signal (noise), 1-srch f sync & data, 2-sync ct & start-bit srch, 3-data-inp;
;aborts prg if rt butn prsd

 mov blkend, 0
 
nxtsmpl:
 call rdadc ;read sample fr tape

 cmp invt, 1
 jne noinvt
 neg al
 cmp al, 0
 jne noinvt
 mov al, 0ff
noinvt:

 cmp al, lv
 je cont2 ;ignore const parts, bec of pt-of-inflection prob (neg-const-neg)
 mov cv, al ;update curr ad-val

 call dettp
 je cont1 ;signs equal: no tp detected;
 call tpdif

 call volchk
 cmp sig, 0
 jne somsig
 mov outcol b, blk
 call pxer
 jmp cont1
somsig:
 cmp stpd, 0
 jne negswing
cont2:
 jmp cont1
negswing:

;calc ratio of curr & prev neg swing
 mov al, tpd
 mov cl, l2tpd
 mov bl, 3 ;set equality-factor-limit
 cmp sig, 3 
 jne notindat2
 add bl, 1
notindat2:
 call idrat
 mov dh, tpd
 mov l2tpd, dh ;update l2tpd

 cmp sig, 3
 jne fnddat
 call rdbit
 jc cont1
rstsig1:
 jmp rstsig

fnddat:
 call fndsydat
 jc rstsig1
 cmp blkend, 0
 jne ret

cont1:
 mov dh, cv
 mov lv, dh ;update lv

 cmp sig, 0 ;only chk btns if no signal
 jne nobtn
 sti
 call getbtn ;mouse button chk
 jc abort
 cli
nobtn:
 jmp nxtsmpl

abort:
 mov al, 'A' ;Aborted
 jmp erxit


dettp:
;detect turning pt
;sets vars for next check
;exits with Z clr, iff tp at prev point

 mov al, cv
 sub al, lv ;subtr old from new val: pos if going up;
 mov ah, 0 ;prep ah for C
 rcl ah, 1 ;save C in ah
 mov bh, ah ;save new sign of d
 xor ah, sld ;chk for chg of sign, ie: turng pt; 0 (Z=1) if equal;
 mov sld, bh ;sign-chk done, save new sign;
 ret


tpdif:
;calc tp-chg
;< al: absol value of tp-chg;
;< tpd(=al), stpd, ltp;

 mov al, lv ;get curr tp-val (=last value read!)
 sub al, ltp ;subtr last tp
 mov dh, lv
 mov ltp, dh ;update ltp
 mov stpd, 0 ;prep f rcl
 rcl stpd, 1 ;save sign
 cmp stpd, 0 ;chk sign (unfort C is clrd & Z not set by rcl!)
 je savtpd
 neg al ;make val absol
savtpd:
 mov tpd, al ;update curr tpd
 ret


volchk:
;checks whe vol not extremely low (always) or high (durg sig2-phase only)
;exits if vol too high for hivolwt
; (-erron hi-signals durg 1&3, even if longer, Must not trigger this, since it exits!)
; -if vol durg sig2-phase is ok, then the vol-knob was set at a correct level & any too-high phases are likely to be only short bursts (due to tape-obstructns, f ex);
;> al: absol(tpd)
;< sig: set to 0, if too low for longer than lovlwt;

;low vol chk
 cmp al, lovlbd
 ja notlo
losig:
 cmp wtlv, lovlwt ;chk acc-bd first, to stop countg if it exceeds alr;
 jae nosig
 inc wtlv
 ret
nosig:
 mov sig, 0
 mov outcol b, blk
 call pxer
 ret
notlo:
 cmp sig, 0
 ja insig
 mov sig, 1
insig:
 mov wtlv, 0 ;reset

;high vol chk
; cmp sig, 2
; jne ret ;only check vol durg sig2
 cmp al, hivlbd
 jae hisig
 mov wthv, 0
 ret
hisig:
 cmp wthv, hivlwt
 jae vtoohi 
 inc wthv
 ret
vtoohi:
 mov outcol b, red
 call pxer
 call pxer
 call pxer
 ret

rstsig:
;an error occured in the signal -> reset to no-sig;
;and save rst-ptr if inside data
 
 mov outcol b, blk
 call pxer
;compare tapdat-ptr to last saved (if any) rstptr
 mov ax, tapdat
 mov bx, rsterr
 call ptrcntcmp ;compares last cont of rsterrt to curr tapdat-pos;
 jnz chkcmp ;no buf empty, compare done
 jnc nosav ;no data yet in tapdat
chkcmp:
 jnc nosav ;last rsterr-ptr equal to curr tapdat-ptr (ie.a reset at this posn has alr occurred)
 mov outcol b, wht ;wht pix for an addition into rsterr-buffer;
 call pxer
 mov ax, tapdat
 mov bx, rsterr
 call ptrtobuf ;update rsterr-table with curr pos
nosav: 
 cmp sig, 3
 mov sig, 0
 jb not4
 mov sig, 4
not4:
 mov bitpt, 0
;should syncct be reset?-not yet used;
 jmp cont1


fndsydat:
;search for sync & data simultan (in yet undefd signal);
;> al & bl: ratio-id (al signed, bl absol) of last 2 down-swings (tpdchg);
;chks whole of start-bit before data accepted
;< C set iff rst-cond

;chk f 2nd part of start-bit
 cmp bitpt, 1
 jb stb0
 cmp al, -1 ;down-factor up to 2.5 allowed
 jne retC1
 mov outcol b, mag
 call pxer
 mov sig, 3
 mov bitn, 2
 mov bitpt, 0
 clc
 ret
 
retC1: 
 stc
 ret

stb0:
;chk f 1st part of start-bit
 cmp al, 0
 je sync
 mov wtsy, 0 ;sig1- or sig2-phase broken (or not started)
 cmp sig, 1
 je ret ;C0
;sig=2 or 4: ;if sig4, resets will show in pxer but not be saved due to the data-written-tests in rstsig;
 ;is it stb ?
 cmp al, 0
 js retC1 ;neg chk
 cmp al, 3
 ja retC1 ;too large swing for start-bit (spike poss)
 mov bitpt, 1 ;1st half of st-bit read, sig not yet incd;
 clc 
 ret


sync:
 cmp sig, 4 ;sync after data
 je sig14
 cmp sig, 1
 je sig14
;within sig2:
 mov outcol b, blu
 call pxer
 inc syncct ;syncct not used yet, rely on sync-phases being found;
 ret ;C0 fr cmp
sig14:
 mov outcol b, cyn
 call pxer
 inc wtsy
 cmp wtsy, syncwt
 jae sig2
 clc
 ret
sig2:
 mov sig, 2
 mov wthv, 0 ;reset hivol-ctr, since it might still be set from a prev sig2-phase;
 mov si, tapdat
 call getptr
 cmp di, 0 ;is there any data yet?
 je ret ;C0 since di>0
 mov blkend, di
 ret


rdbit:
;read bit in data
;> al: tpdchg;
;C clr iff rst-error

 cmp bitpt, 0
 ja bit2nd
 mov bitpt, 1
 stc
 ret
bit2nd: ;second half of bit
 mov bitpt, 0 ;reset bit-part f next bit
 cmp bitn, 1
 ja inbyt
 cmp al, 0 ;al=idrat of last 2 down-swings
 js stbok ;neg value: start-bit found;
 ret ;C clr fr cmp ->rst;
stbok:
 mov outcol b, mag
 call pxer
 inc bitn ;bitn=2
 stc ;exit ok
 ret
inbyt: 
 cmp al, 0 ;swings of the 2 halves of bit unequal?
 jne datbitok
cmp mbuts b, 0
je notmbuts2
call wtbtn
jmp erxit
notmbuts2:
 clc
 ret ;C clr fr cmp
datbitok:
 mov outcol b, grn
 call pxer
 cmp bitn, 10
 jb notpar
;parity bit
 call parchk
;save byte
 mov al, byt
 mov bx, tapdat
 call wrtbuf
 mov bitn, 1
 stc ;exit ok
 ret
notpar:
 sal al, 1 ;C=sign-bit
 rcr byt, 1
 inc bitn
 stc ;exit ok
 ret


parchk:
;perform parity check of recorded par-bit with calc pb
;save err-loc, if err
;> al'7 =pb fr tape

 mov bl, byt
 or al, al ;S=pb fr tape
 js tappar1
;tape-pb =0
 or bl, bl ;P=pb of byte read
 jnp ret
 jp prerr
tappar1: 
 or bl, bl
 jp ret
prerr:
 mov ax, tapdat 
 mov bx, parerr 
 call ptrtobuf
 ret


fndrsts:
;find rst-err posns in retrieved blks
;<C1: cnt-dn not fd;
;<bl: corrpt blks: b0=1st, b1=2nd blk;
;<ax: pos of cnt-dn = end of blk1 (+1) = start of blk2 (incl cnt-dn);
;(<cdpos: =<ax;

 mov si, tapdat
 mov ax, cntdn ;find part of cnt-dn string
 mov di, 1 ;skip first cnt-dn!
 mov cx, 9
 call srchbuf
 jc ret ;not fd: data corrupt
 mov cdpos, di

 mov ax, di
 mov si, rsterr
 call srchmonb
 jc erxit1

 mov bl, 0 ;init corpt-blk-id
 cmp di, 0
 je blk1ok
 add bl, 1 ;blk 1 corrupt
blk1ok:
 sub dx, di
 cmp dx, 4 ;there are 2 normal resets: at end & at cdpos;
 je blk2ok
 add bl, 2 ;blk 2 corrpt
blk2ok:
 clc
 ret

erxit1:
 mov al, 'X' ;bug!
 jmp erxit


cntdn:
 db 9,8,7,6,5,4,3,2,1


rtrhdr:
;m7u: retrieve header-data
;(<hdrok, fstrt, fnam, flen;

 mov hdrok, 0 ;assume hdr faulty
 mov si, parerr
 call getptr
 cmp di, 0
 ja setinfo ;some perrs
 mov si, rsterr
 mov ax, 30
 call srchmonb
 cmp di, 0
 ja setinfo
 mov hdrok, 1 ;hdr ok

setinfo:
;set up hdr-info

 mov al, b[tapdat0+9] ;copy hdr-id
 mov blkid, al
 mov fstrt, w[tapdat0+10] ;copy file start
 cmp hdrok, 0
 jne hdrok4
 mov blkid, 0 ;don't trigger seq-readg if hdr corrpt!
 mov fstrt, 01001 ;if hdr corrpt, use the usual start adr;
hdrok4:
 mov si, tapdat0 ;copy file-name
 add si, 14
 mov cx, 16
 mov di, fnam
 call cops
 mov bx, fnam
 mov si, 16
 call nrmstrg ;replace any ctrl-chrs (poss in file-name, when salvgg)

 mov ax, w[tapdat0+12] ;copy file-end & calc length
 sub ax, fstrt
 mov flen, ax
 ret


prtfnam:
;32o4i: prt out file-name, so as not to obscure gr-outp;

 call mvcrsclr
 mov bx, fnam
 mov cx, 16
 call outp
 mov al, ' '
 call wrt
 mov al, 'P'
 cmp blkid, 1
 je prgtyp2
 mov al, 'S'
 cmp blkid, 4
 je prgtyp2
 mov al, 'C'
 cmp blkid, 3
 je prgtyp2
 mov al, 'X'
prgtyp2:
 call wrt
 ret


rtrfil:
;retrieve file-data
;(<datok, svstrt, flen2;

 mov datok, 0 ;assume data faulty
 mov svstrt, tapdat0 ;assume salvage

 call fndrsts
 jc salv1
 cmp bl, 3
 jb oneclr ;at least one blk clr of rst-errs
salv1:
 mov ax, blkend
 mov flen2, ax
 ret

oneclr:
 push bx
 mov si, parerr ;ax alr set up by fndrsts
 call srchmonb ;find pos of cnt-dn in parerr-buf
 pop bx

;set up datok
 mov al, 0 ;use al as parerr-flags reg; assume both blks clr;
 jc b2ok
 cmp di, 0
 je b1ok
 or al, 1
b1ok:
 cmp di, dx
 je b2ok
 or al, 2
b2ok:
 or al, bl ;add errs f both rsts & par tog;
 xor al, 0ff ;invert bits
 and al, 03 ;mask out low 2b
 mov datok, al

 add svstrt, 9 ;skip init cnt-dn seq
 mov ax, cdpos
 sub ax, 10 ;9 ct-dn vals + 1 chksum-byte
 mov flen2, ax
 test datok, 1
 jnz ret ;blk 1 ok;
;blk 1 corpt, use blk 2
 mov ax, cdpos
 add svstrt, ax
 mov ax, blkend
 sub ax, cdpos
 sub ax, 9
 mov flen2, ax
 ret

 
savfil:
;update save-log & save data, as salvage-file (w flen2), or as .bin-file (w flen & fstrt);

 mov bx, obuf

;fnum & trailg spc
 mov si, 0
 mov al, fnum
 clc
 call hxaso ;convt to hex chrs, into obuf
 mov al, ' '
 call appdo 

;hdr-err-typ & spc
 mov al, '0'
 add al, hdrok ;convt to asci
 call appdo
 mov al, ' '
 call appdo

;file-type: Prg/Seq;
 mov al, 'P'
 cmp blkid, 1
 je prgtyp
 mov al, 'S'
 cmp blkid, 4
 je prgtyp
 mov al, 'C';Char.set file-type?
 cmp blkid, 3
 je prgtyp
 mov al, 'X' ;corrpt hdr
prgtyp:
 call appdo
 mov al, ' '
 call appdo

;file-name & spc
 push si
 mov di, si
 add di, bx
 mov si, fnam
 mov cx, 16
 call cops
 pop si
 add si, 16
 mov al, ' '
 call appdo

;start-adr, spc, len, spc;
 mov ax, fstrt
 stc ;2 bytes
 call hxaso
 mov al, ' '
 call appdo
 mov ax, flen
 stc
 call hxaso
 mov al, ' '
 call appdo

;data-err-typ
 mov al, '0'
 add al, datok ;convt to asci
 call appdo
 mov al, ' '
 call appdo

;saved-len
 mov ax, flen2
 stc
 call hxaso

 ;new line
 mov al, 0d
 call appdo
 mov al, 0a
 call appdo

 push si 

 cmp savon, 0
 je nosav3
 mov ax, svlog
 mov cx, si
 mov dx, bx
 stc ;write
 call fop1
nosav3:

;& also prt out:
 call mvcrsclr
 pop si
 mov cx, si
 mov bx, obuf
 call outp

;save data
 cmp savon, 0
 je ret
 mov b[obuf+2], 0 ;0-terminate file-name (asci-num at strt of obuf!);
 mov ax, obuf
 mov cx, flen2
 mov dx, svstrt
 cmp datok, 0
 je salv3
 stc ;save in .bin-fmt
 mov bx, fstrt ;start adr f bin-fmt
 call svfil
 ret

salv3:
 call svbufs
 ret

;-------------------includes----------------------------

include io5.asm
include sbdsp.asm
include pxer2.asm
include num2.asm
include buf3.asm
include hd2.asm
include strg2.asm
include m.asm


