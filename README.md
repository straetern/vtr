# VIC-20 Tape Reader (VTR)

This is a program in x86-Assembler written by me in 1997 for data migration from magnetic tapes produced by the VIC-20 Home Computer (by Commodore in the 1980s) to a PC using a soundcard.

By the late 90s I had long since stopped using the VIC-20 (my first computer) and switched to the PC, but I still wanted to be able to run my first self-written programs and some old games on the PC using an emulator. I could not then find a satisfactory solution to do this and although it could be done with disk drives, I could not afford one at the time, so I wrote this. You had to run the data tapes on which the programs were stored on a normal tape recorder (not the VIC-20 special recorder), connect the recorder's output to the PC's soundcard input, and while vtr was running observe the screen for a graphical display with different colours representing the data signals on the tape and then fiddle with the recorder volume controls until synchronization occurred. I remember being pretty happy with the way the visual feedback of what the program was seeing enabled one to achieve the required synchronization and the way the colours helped to do this. The program was then able to read the files off the tapes and save them on the PC, from where they could be loaded into an emulator. 

I never personally uploaded this to the community, but sent it to an interested person in New Zealand who published it on a bulletin board. The license was a simple freeware type one liner similar to the MIT License, under which I am placing it now.

I was told many years later that a number of other people managed to use this successfully to migrate their VIC-20 data tapes onto the PC, in addition to myself. Although this no longer serves any useful purpose, it might be interesting to some since it's written completely in x86-Assembler, so I'm uploading it here for curiosity. Yes that's 25 years too late, but better late than never :-)

I left it unchanged, the Readme with usage instructions is the file vtr.txt.
