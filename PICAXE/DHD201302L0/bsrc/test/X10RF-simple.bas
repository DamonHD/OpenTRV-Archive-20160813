; *************************************************************
;
; The OpenTRV project licenses this file to you
; under the Apache Licence, Version 2.0 (the "Licence");
; you may not use this file except in compliance
; with the Licence. You may obtain a copy of the Licence at
;
; http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing,
; software distributed under the Licence is distributed on an
; "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
; KIND, either express or implied. See the Licence for the
; specific language governing permissions and limitations
; under the Licence.
;
; *************************************************************
; Author(s) / Copyright (c): Jonathan Burchell 2009,
;                            Damon Hart-Davis 2013

; Attempt to get simple X10 transmission working.

; For 18M2+ on AXE091
#picaxe 18M2

; Default 4MHz clock.
gosub setNormalClockSpeed

; IF DEFINED: in the absence of an RTC, and to keep sync with remote devices, keep on-chip elapsed time measure as good as possible.
; #define KEEP_ELAPSED_TIME_ACCURATE

; No RTC required.


; INPUT SENSORS
; Momentary button to toggle between off and warm modes (logic-level input).
symbol BUTTON_MODE = C.1
input BUTTON_MODE


; OUTPUT INDICATORS
; Green 'temp OK' LED.  (LED1 on AXE091, B.1 on 18M2)
symbol LED_TEMPOK = B.1
output LED_TEMPOK
; Red 'calling for heat' LED.  (LED3 on AXE091, B.3 on 18M2)
symbol LED_HEATCALL = B.3
output LED_HEATCALL
; Yellow 'aux' LED, mainly for testing/dev.  (LED3 on AXE091, B.3 on 18M2)
symbol LED_AUX = B.2
output LED_AUX

; OTHER OUTPUTS
; X10 TX out (directly drives OOK radio).
symbol X10TX = B.7
output X10TX
low X10TX ; send low ASAP 


;-----------------------------------------
; GLOBAL VARIABLES


; W3 (AKA B6 & B7) as X10 output command word
; Word sent over X-10 on request.
symbol X10WordOut = w3
symbol X10WordOutLSByte = b6
symbol X10WordOutMSByte = b7
; X10 command to turn on the boiler on.
symbol X10BoilerOn  = %0110000000000000 ; A1 ON
; X10 command to turn on the boiler off.
symbol X10BoilerOff = %0110000000100000 ; A1 OFF

; W6 & W7 (aka b12, b13, b14, b15)
; Used by ConvertTotxMap X10 support routine.
symbol txWord0=w6
symbol txWord1=w7
' How to view the txWords as bytes
symbol txByte0=b12 
symbol txByte1=b13
symbol txByte2=b14
symbol txByte3=b15

; TEMP
; B16 & B17 & B18 & B19 (aka W8 & W9)
; Temp/scratch bytes 0 & 1 and OVERLAID word 0.  Not expected to survive subroutine calls, etc.
symbol tempB0 = b16
symbol tempB1 = b17
symbol tempW0 = w8
symbol tempB2 = b18
symbol tempB3 = b19
symbol tempW1 = w9

; OTHER MEMORY
; 0x50: More X10 transmit support memory.
symbol BitMemLow=0x50                 ;Start of 32 byte memory area with data to TX
symbol BitMemMiddle=BitMemLow+16      ;Where the second 16 bits start
symbol BitMemHigh=BitMemLow+31        ;The last location of our 32 bit map
;-----------------------------------------


; Main loop; never exits.

do
    high LED_AUX
    X10WordOut = X10BoilerOn
    gosub X10Send
    pause 5000
    low LED_AUX
    X10WordOut = X10BoilerOff
    gosub X10Send

mainLoopCoda:
    ; Tail of main loop...
    ; Sleep in lowest-power mode that we can for as long as we reasonably can.
       
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 5000
#else
    disablebod
    sleep 2 ; TODO: lengthen if we know nothing critical is scheduled in the next second or so...
    enablebod
#endif

loop ; end of main loop


; X10 support definitions.
; X-10 RF timings are: initial 8.8ms burst, 4.4ms silence; 2.2ms for binary 1 and 1.1ms for binary 0.
symbol PreambHigh=3720                ;This generates an 8 ms preamble @ 16MHz.
symbol PreambLow=16                   ;This generates an 4 ms pause @ 16MHz.
symbol OneDelay=2                     ;This is half the delay needed, ie 0.5ms @ 16MHz.
symbol ZeroDelay=0
symbol BitEnd=150  
symbol BetweenTryDelay=160            ;40 ms between tries (@ 16MHz).
;
symbol Memptr = tempB0
symbol tmpByte = tempB1
symbol Tries = tempB2

; Send 32 bits using table set up by ConvertTotxMap.
rfX10:
	gosub setHighClockSpeed
	low X10TX ; Ensure correct starting value...
    for Tries = 1 to 3                            'Try to send the data three times (3--7 is common).
        ; It takes ~108ms to send one X10 code including pause afterwards.
	    pulsout X10TX,PreambHigh                  'Send the preamble pulse
	    pause PreambLow                           'wait 4 millisecsonds
	    for Memptr = BitMemLow to BitMemHigh      'Now send bits of data
	        high X10TX                            'First rising edge
	        peek Memptr,tmpByte                   'Get the delay which sets if this will be a one or zero
	        pause tmpByte                         'Do half the delay - You could use pulsout DummyPin,Delay
	        low X10TX 'Let the tx drop - we are still within a bit
	    pause tmpByte                             'Do the rest of the delay
	    next Memptr
	    pulsout X10TX,BitEnd                      'We need the final rising edge
	    pause BetweenTryDelay                     'Pause between send tries
    next Tries         
    gosub setNormalClockSpeed 
    return

; ConvertTotxMap 32 bytes
;
; The 32 byte table that rf X10 uses can be built in any number of ways - It is simply the 32 bits to be sent
; laid out in transmit order, with zero for a zero bit and OneDelay for a one bit.
; Below is a short helper routine that can take a 32 bit input (2 word registers) and convert
; them to the 32 byte table that rf X10 needs. The input registers can be any but they must be usable as words.
; txWord0 is destroyed by this code.
; Note X10 sends the LSB of each byte first
ConvertTotxMap:
  Memptr = BitMemLow                  ;Where to start the table
  do
  tmpByte = txWord0 ** 2 * OneDelay   ;Shift 1 left, get the fall out bit * delay.
    txWord0 = txWord0 * 2             ;update the actual word
    poke Memptr,tmpByte               ;save the bit time length
    Memptr = Memptr+1
    if Memptr = BitMemMiddle then let txWord0 = txWord1 endif   ;swap after 16
  loop while memptr <= BitMemHigh
return


; Sends X10WordOut, most significant byte first.
; Based on J C Burchell version 1.0 2009 code at https://docs.google.com/document/pub?id=1dF5rpRkv-Ty3WcXs8D9Oze86hR50ZI96RzNrMvd_S0U
; For underlying protocol description see: http://davehouston.net/rf.htm
; Runs overspeed in parts to meet timing constraints, though does not disturb 'time' elapsed time behaviour.
X10Send:
    txByte0 = X10WordOutMSByte           ;Destroyed by ConvertTotxMap
    txByte1 = X10WordOutMSByte ^ 0xff    ;In X10 second byte is complement of first.
    txByte2 = X10WordOutLSByte
    txByte3 = txByte2 ^ 0xff             ;In X10 last byte is complement of third.
    gosub ConvertTotxMap
    gosub rfx10
    return











; Set the default clock speed (with correct elapsed-time 'time' behaviour).
setNormalClockSpeed:
    setfreq m4
    return

; Set a high clock speed (that preserves the elapsed-time 'time' behaviour).
; http://www.picaxe.com/BASIC-Commands/Advanced-PICAXE-Configuration/enabletime/
setHighClockSpeed:
    setfreq m16
    return

 
; Take a tiny pause, saving power if possible without losing timing accuracy.
tinyPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 20
#else
    nap 1
#endif
    return
; Take a medium pause, saving power if possible without losing timing accuracy.
mediumPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 72
#else
    nap 2
#endif
    return
; Take a significant pause, saving power if possible without losing timing accuracy.
bigPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 576
#else
    nap 5
#endif
    return









    
    
    
#rem
; Original at 8MHz on 08M from https://docs.google.com/document/pub?id=1dF5rpRkv-Ty3WcXs8D9Oze86hR50ZI96RzNrMvd_S0U

; With permission from the author:
;--------------------------
Sent: 21 January 2013 16:35
To: Jonathan Burchell
Subject: [Jonathan Burchell's Blog] New comment on X10 RF transmitter using PICAXE 08M.

Hi,

Do you have any objection to me deriving something from this code for the open-source TRV project (OpenTRV)?

http://www.earth.org.uk/open-source-programmable-thermostatic-radiator-valve.html

Rgds

Damon Hart-Davis 
;--------------------------
	From: 	Jonathan Burchell
	Subject: 	FW: [Jonathan Burchell's Blog] New comment on X10 RF transmitter using PICAXE 08M.
	Date: 	21 January 2013 16:49:51 GMT
	To: 	d@hd.org Hart-Davis

Hi,
 
 
                Knock yourself out Ð only thing I would point out Ð I write this for the M series PICAXE that had a maximum speed of 8 MHZ, the new M2 devices can be set to run at 32 MHZ Ð at that speed there is probably enough time to transmit the bits from a select the bit, is it a one or a zero type loop
 
Having said that 8 Mhz does not use at much power, the code does work and is time was a way to do quick bit times on a slow device Ð should help with getting your existing stuff going again
 
-          Jonathan
 
Great project by the way
;--------------------------


X10RFDemo

#picaxe 08m

'

' J C Burchell version 1.0 2009

'

' X10 RF out on Picaxe08m in 39 program bytes and 32 storage bytes

'

' Sends out bits of data, with X10 RF timing

'

' In X10 RF a One Bit has 2.2 ms between rising edges and a Zero bit 1.1 ms

'

' Even running the part at 8Mhz, there is not enough time to do a standard bit mask

' and IF type output pulse selection, let alone actually fetch the databytes in an inner FOR loop

' To get around this we transmit from a n byte table - where each byte contains simply the

' delay factor to insert for the bit that is to be transmitted.

'

' By using a lookup table we can avoid the need for any bit testing or IF decisions, AM often demodulates better

' when the DC component is near zero - To help with this we try to keep the high and low times within

' a One or Zero bit around 50:50

'

goto main

symbol txPin=2                       'The pin that goes to DataIn on the TX module

symbol BitMemLow=0x50                 'Start of 32 byte memory area with data to TX

symbol BitMemMiddle=BitMemLow+16      'Where the second 16 bits start

symbol BitMemHigh=BitMemLow+31        'The last location of our 32 bit map

symbol PreambHigh=1860                'This generates an 8 ms preamble @ 8Mhz

symbol PreambLow=8                    'This generates an 4 ms pause @ 8Mhz

symbol OneDelay=1                     'This is half the delay needed

symbol ZeroDelay=0

symbol BitEnd=150  

symbol BetweenTryDelay=80             '40 msec between tries

symbol Memptr=b13                     'Pointer to the memory map of bits

symbol Tries=b12                      'Counter for the numbers times we send the data

symbol tmpByte=b11                    'tmp variable

' We assume that the tx module is already powered on, and the datain pin is low and that it goes high

' to send data - Some sort of hardware init code will normally have done this - though the RF Solutions RT5

' only draws 50 nanoamps when datain is low, so there is no need to bother with powering the device, it can be

' permanently connected

   

   

rfX10:

   

setfreq m8                                'Set speed to 8 Mhz

  for Tries = 1 to 3                        'We will try to send the data three times

    pulsout txPin,PreambHigh                'Send the preamble pulse

    pause PreambLow               'wait 4 millisecsonds

    for Memptr = BitMemLow to BitMemHigh    'Now send bits of data

      high txPin                            'First rising edge

      peek Memptr,tmpByte                   'Get the dealy whichs sets if this will be a one or zero

      pause tmpByte                         'Do half the delay - You could use pulsout DummyPin,Delay

      low txpin 'Let the tx drop - we are still within a bit

    pause tmpByte                         'Do the rest of the delay

    next Memptr

pulsout txPin,BitEnd                      'We need the final rising edge

  pause BetweenTryDelay                     'Pause between send tries

  next Tries

               

  setfreq m4                                'Restore speed

  return

' ConvertTotxMap 32 bytes

'

' The 32 byte table that rf X10 uses can be built in any number of ways - It is simply the 32 bits to be sent

' laid out in transmit order, with zero for a zero bit and OneDelay for a one bit.

' Below is a short helper routine that can take a 32 bit input (2 word registers) and convert

' them to the 32 byte table that rf X10 needs. The input registers can be any but they must be usable as words.

' txWord0 is destroyed by this code.

' Note X10 sends the LSB of each byte first

symbol txWord0=w1      ' b3:b2

symbol txWord1=w2      ' b5:b4

' How to view the txWords as bytes

symbol txByte0=b3 

symbol txByte1=b2

symbol txByte2=b5

symbol txByte3=b4

ConvertTotxMap:

  Memptr = BitMemLow                  'Where to start the table

  do

  tmpByte = txWord0 ** 2 * OneDelay 'Shift 1 left, get the fall out bit * delay

    txWord0 = txWord0 * 2             'update the actual word

    poke Memptr,tmpByte               'save the bit time length

    Memptr = Memptr+1

    if Memptr = BitMemMiddle then let txWord0 = txWord1 endif   'swap after 16

    loop while memptr <= BitMemHigh

return

    

' Simple demo, sends code On then Off every 30 seconds

' Look at the CM17 protocol for the codes ftp://ftp.x10.com/pub/manuals/cm17a_protocol.txt

' For the Demo we will use

' A2 ON 0x60 0x10 and A2 OFF 0X60 0x30  - We can flip between the on and off codes with an XOR

  

symbol firstbyte = 0x60

symbol secondbyte = 0x30

symbol ToggleCode = 0x20

main:

  txByte2 = secondbyte

  forever:

   txByte0 = firstbyte           'Destroyed by ConvertTotxMap

   txByte1 = txByte0 ^ 0xff       'In X10 second byte is complement of first

   txByte2 = txByte2 ^ ToggleCode 'Switch between on and off, preserved by ConvertTotxMap

txByte3 = txByte2 ^ 0xff       'In X10 last byte is complement of first

   gosub ConvertTotxMap

   gosub rfx10

sleep 13

   goto forever

end

#endrem
