;32j1i: num.asm = numerical routines;
;
;error-exits:
; 'Z' = div by zero;
;-----------------------------------------

rgchk:
;g7a: chks wh al within rge [bl,bh]: c=1 iff true;
;al & bx unchanged;
 cmp bl, al
 ja nir1 ;not in rge
 cmp al, bh
 ja nir1
 stc
nir1:
 ret


idrat:
;'identify' (or: characterise) the ratio betw al & cl
;o3a: added var-chk on equality, factor given in bx;
; 0: equal: 1.0-1.25;
; +/-1: (1+1/bx)-2.5;
; +/-2: 2.5-3.5;
; +/-3: >3.5;
;
;> al, cl
;> bl: equality-limiting factor: =(1+1/bx) - ie: 3 gives 1.33, 4 gives 1.25;
;< al: signed ratio-id, bl: abs(al);
;

 mov el, bl
;safety-check: al & cl>0!
 cmp cl, 0
 je zero
 cmp al, 0
 ja not0ok
zero:
 mov al, 0
 mov bl, 0
 ret
 mov al, 'Z' ; Z f zero
 jmp erxit
not0ok:
 mov bh, 0 ;sign pos
 cmp al, cl
 jae noswop
 mov bh, 1 ;sign neg 
 mov bl, al ;save al
 mov al, cl ;swop1
 mov cl, bl ;swop2
noswop:
 mov ah, 0 ;'div' in asm is alw f ax!
 div cl ;gives quot in al, remdr in ah; ltpd cannot be zero!;
 mov dl, al ;save quotient
 mov al, cl ;need divisor once more for remdr calc
 mov dh, ah ;prep f Div: save remdr
 cmp dh, 0
 ja remnot0
 mov bl, 0ff ;max poss val (means: remndr as small as poss)
 jmp crtid 
remnot0:
 mov ah, 0 ;set up ax
 div dh ;div divisor by remdr to find how close divisor was to dividend
 mov bl, al ;save 2nd divisor
crtid:
;create tpdchg
 mov al, 0 ;id f equality
 cmp dl, 1
 ja grtr1
 cmp bl, el
 jae r4 ;it's '0' ;ie: <=(1+1/el);
 inc al ;it's '1'
 jmp r4
grtr1:
 inc al ;it's '1'
 cmp dl, 2
 ja grtr2
 cmp bl, 2 ;up to 2.5
 jae r4
 inc al ;it's '2' (2.5-3.0);
 jmp r4
grtr2:
 inc al ;it's '2': 2.5-3.5
 cmp dl, 3
 ja grtr3
 cmp bl, 2
 jae r4 ;up to 3.5
grtr3: 
 inc al ;it's '3': >3.5
r4:
 mov bl, al ;keep copy of absol value
 cmp bh, 0 ;chk saved sign
 je ret ;pos tpd-chg
 neg al
 ret



