; (c) Jeremy Harris 2013
; Supplied AS-IS with NO WARRANTIES OF ANY KIND.

;433MHz RF receiver to decode HomeEasy wireless switch signals into 10 bytes of ASCII hex
;should work OK with transmitter switches like the HE307 single wall switch, the HE308 double wall switch, the HE305 magnetic door switch and the HE303 PIR switch
;may also work with the HE300 5 way remote and the HE301 keyfob remote.  Probably doesn't work with the HE200 remote, but might work with the HE100
;HomeEasy data format for these (often called the "automatic protocol") is 32 bits of data sent as a 64 bit Manchester encoded RF data packet
;data packets are repeated several times for each key press
;data format is:
;there is ~10mS gap between data packets
;the start of a data packet is signalled as a 270 to 300µS pulse followed by a gap of ~2.6mS
;a "0" is transmitted as a 270 to 300µS pulse followed by a 270 to 300µS gap before the next 270 to 300µS pulse
;a "1" is transmitted as a 270 to 300µS pulse followed by a 1100 to 1300µS gap before the next 270 to 300µS pulse

;This is pushing the boundaries with the limited speed that a Picaxe can operate at, the code has been tweaked to get the
;critical bit (measuring and storing the pulse length) to run as quickly as possible and seems to work reliably now.
;
;the detection gate timing in "detectpacket" may possibly need tweaking for individual resonator frequency differences between chips.  If the
;switches aren't detected reliably then try moving the detection window times up or down a bit. 


;The decoder works by measuring the width of 64 transmitted negative going pulses and storing them in a linear data array as two bytes per measurement
;this is then decoded by looking at every second negative going pulse (the one that determines whether the Manchester encoded bit is a "0" or "1")
;and any negative going pulse width between 187.5µS and 312.5µS is assumed to be a "1"
;This 32 bit word is then converted to ASCII hex and transmitted out of the serial port as ten ASCII characters at 9600 baud.
;
;The output data format is ten ASCII characters representing ten HEX nibbles, like this: 142C6A201A.
;The first 7 characters are the 26 bit unique device address, with the last byte only representing 2 bits, rather than 4.
;For example, the 7 first ten characters, 142C6A2, represent the device address 00010100001011000110101010 in binary
;
;The next hex character, 0, is the state of the group flag, a flag used to indicate that devices are part of a group switched by a common transmitted code.
;
;The next hex character, 1, is the switch on/off state and is the only bit to change when a switch on a device is changed from one state to another.
;
;The final character, A, is the device code.  This allows up to 16 different switches (0000 to 1111, or 0 to F hex) to be individually accessed using one unique device address.
;
;


#Picaxe 14M2


SYMBOL pulselength = w0
SYMBOL lobyte = b0
SYMBOL hibyte = b1
SYMBOL bitvalue = b2
SYMBOL addressbyte1 = b3
SYMBOL addressbyte2 = b4
SYMBOL addressbyte3 = b5
SYMBOL addressbyte4 = b6
SYMBOL addressbyte5 = b7
SYMBOL addressbyte6 = b8
SYMBOL addressbyte7 = b9
SYMBOL flagbyte = b10
SYMBOL onoffbyte = b11
SYMBOL devicebyte = b12
SYMBOL loopcounter = b13
SYMBOL tempbyte = b14


initialise:
	setfreq m32							;@32MHz clock speed, pulsin count increment is 1.25µS
	LOW c.1							;LED off. LED is an indicator that the receiver has detected a signal with the right sort of initial pulse width
		

detectpacket:							
	
	pulsin c.2,0,pulselength
	

	IF pulselength < 7900 THEN GOTO detectpacket
	IF pulselength > 8200 THEN GOTO detectpacket
	PAUSE 10
	
	HIGH c.1							;LED on
	
getpacket:
	
	bptr = 28 							;fill up available variable storage with consecutive low pulses as fast as possible (1.25µS resolution)
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte						;pulse length word is stored as two consecutive bytes, 64 bytes (32 words)
	@BPTRINC = hibyte

	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte

	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte

	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTRINC = hibyte
	
	pulsin c.2,0,pulselength
	@BPTRINC = lobyte	
	@BPTR = hibyte						;byte pointer is 155 at this point, so locations 28 to 155 contain 128 bytes of Manchester
									;encoded pairs, representing 64 bits which gives 32 data bits.  01 = 0 and 10 = 1
		
	LOW c.1							;LED off
	
	
decodepacket:

	;get first (MS) address byte, followed by another 6 bytes for the 7 bytes that hold 4 bits each (26 transmitted bits in total) of the unique transmitted address
	;note that the LS byte only holds two bits
	
	tempbyte = 0						;ensure final output byte start as zero
	
	FOR bptr = 28 to 43					;read back pulse length and reconstruct original words (first 64 Manchester bit pairs)				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr					;only read every other stored pulse length, as Manchester can be decoded from just the second bit of each pair
		
									;trap some errant pulses that might get through the initial trigger gate
		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0 					;read second pulse length of the pair and set the appropriate bit value
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue		;multiply by two to shift the bits left and add the bit value
	NEXT
	
	GOSUB bin2ASCIIhex
	addressbyte1 = tempbyte

	tempbyte = 0
	
	FOR bptr = 44 to 59				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr
		
		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT
	
	GOSUB bin2ASCIIhex
	addressbyte2 = tempbyte
	
	tempbyte = 0
	
	FOR bptr = 60 to 75			
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr				
								
		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT
	
	GOSUB bin2ASCIIhex
	addressbyte3 = tempbyte
	
	tempbyte = 0
	
	FOR bptr = 76 to 91				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT	
		
	GOSUB bin2ASCIIhex
	addressbyte4 = tempbyte
	
	tempbyte = 0
	
	FOR bptr = 92 to 107				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT
	
	GOSUB bin2ASCIIhex
	addressbyte5 = tempbyte
	
	tempbyte = 0
	
	FOR bptr = 108 to 123				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT
	
	GOSUB bin2ASCIIhex
	addressbyte6 = tempbyte
	
	tempbyte = 0
	
	FOR bptr = 124 to 131					;this only reads 2 bits				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT	
	
	GOSUB bin2ASCIIhex
	addressbyte7 = tempbyte
	
	
	;get the group flag bit, stored as 1 byte
	tempbyte = 0
	
	FOR bptr = 132 to 135					;this only reads 1 bit				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET tempbyte = 0
		ELSE LET tempbyte = 1
		ENDIF
	NEXT	
	GOSUB bin2ASCIIhex
	flagbyte = tempbyte
	
	
	;get the switch on/off bit, stored as 1 byte	
	tempbyte = 0
	
	FOR bptr = 136 to 139					;this only reads 1 bit for on/off select			
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET tempbyte = 0
		ELSE LET tempbyte = 1
		ENDIF
	NEXT	
		
	GOSUB bin2ASCIIhex
	onoffbyte = tempbyte		
	
	
	;get the 4 bit device code, stored as a 1 byte	
	tempbyte = 0						;4 bit device code
	
	FOR bptr = 140 to 155				
		lobyte = @bptrinc
		hibyte = @bptrinc
		lobyte = @bptrinc
		hibyte = @bptr

		IF pulselength < 150 OR pulselength > 1100 THEN GOTO detectpacket
		IF pulselength > 250 AND pulselength <800 THEN GOTO detectpacket
		
		IF pulselength >800 AND pulselength <1100 THEN
		LET bitvalue = 0
		ELSE LET bitvalue = 1
		ENDIF
		
		tempbyte = tempbyte * 2 + bitvalue
	NEXT
	
	GOSUB bin2ASCIIhex
	devicebyte = tempbyte
	

transmithexASCII:	

	HSERSETUP B9600_32, %10					;9600 baud at 32MHz clock, inverted data out (idle low, as used by other peripherals) 
	HSEROUT 0, (b3," ",b4," ",b5," ",b6," ",b7," ",b8," ",b9," ",b10," ",b11," ",b12,CR,LF)
		
	GOTO detectpacket					;loop back to beginning and wait for next data packet
	

	

bin2ASCIIhex:

		
	IF tempbyte > 15 THEN GOTO detectpacket			;trap invalid value in decoded data and restart data acquisition
	
	IF tempbyte < 10 THEN 
	LET tempbyte = tempbyte + 48				;add 48 to convert 0 to 9 decimal to ASCII
	ELSE LET tempbyte = tempbyte + 55			;add 55 to convert 10 to 15 decimal to A to F ASCII
	ENDIF
		
	RETURN

END

