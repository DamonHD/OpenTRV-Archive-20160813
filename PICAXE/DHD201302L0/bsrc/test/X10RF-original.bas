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

; Only alteration is to use 08M2 and the A1 housecode to switch TM12 transceiver model directly.


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
#endrem



'X10RFDemo

;#picaxe 08m
;#picaxe 08m2

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

;symbol secondbyte = 0x30
symbol secondbyte = 0x20 ; DHD20130126 A1 housecode for TM12...

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