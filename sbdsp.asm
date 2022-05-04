;32h4a: sbdsp: read vals from & setup sb16-dsp
;---------------------------------------------


sbadr equ 0220


getvsn:
;get dsp version number: ah.al
 mov ah, 0e1
 call wrtsb
 call rdsb
 mov ah, al
 call rdsb
 ret


setsb:
;reset sb-dsp & set samplg rate
;exit with C=1 if reset not successful
 mov dx, sbadr+06
 mov al, 1
 out dx, al
;wait f 3us
 dec al ;set al to 0 (as done in example)
wtloop:
 dec al
 jnz wtloop
 out dx, al ;al is alr 0 fr prec loop
 mov cx, 0 ;max of 0ffff retries (as in example)
wtrdybt:
 call rdsb
 cmp al, 0aa
 je rstok ;reset ok
 loop wtrdybt
;should give 0aa-val after 100us, if not prod error!;
;prod some exception -?
 stc ;reset fault
 ret
rstok:
;set sampling rate to 44100
 mov ah, 040 ;set transfer time rate
 call wrtsb
 mov ah, 0e9
 call wrtsb
 clc ;reset ok
 ret  


rdsb:
;read sb-dsp, waitg f rdy-status
;val read in al, on exit
 mov dx, sbadr+0e
wtavl:
 in al,dx                      
 or al,al         ;chk f avail smple: b7 of 022e =1;
 jns wtavl        ;wait until avail;
;read data
 sub dx,4         ;DX = DSP Read Data: 022a;
 in al,dx        ;AL = ADC Data
 ret


wrtsb:
;writes ah to sb16-dsp write-cmd-reg
;waits for ready-status
 
 mov dx, sbadr+0c ;write-cmd reg
wtrdy: ;wait until b7 of buf-status is clr
 in al, dx
 or al, al
 js wtrdy
 mov al, ah
 out dx, al
 ret


rdadc:
;setup & read sb-adc with inpu via line-in (or mic, cd ?!);
;value read in al, at 8-bit resoln;

 mov ah, 020 ;setup sb for 'direct adc'
 call wrtsb
 call rdsb
 ret

