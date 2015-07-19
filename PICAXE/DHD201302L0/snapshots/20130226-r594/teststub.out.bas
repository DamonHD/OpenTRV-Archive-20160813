
; GENERATED/OUTPUT FILE: DO NOT EDIT!
; Built 2013/26/02 16:35.
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; Test minimal version of boiler node eavesdropping on FHT8V commands.

#picaxe 18M2


#define BOILER_HUB ; Test RX code...

; IF DEFINED: only use RFM22 RX sync to indicate call for heat from boiler rather than reading the FHT8V frame content.
#define RFM22_SYNC_ONLY_BCFH

; IF DEFINED: use DS1306 RTC for accurate elapsed time measures at least.
#define USE_MODULE_DS1306RTCSPISIMPLE




#ifdef LOCAL_TRV
; IF DEFINED: use RFM22 radio transceiver over SPI.
#define USE_MODULE_RFM22RADIOSIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
; IF DEFINED: use simple FHT8V TX code.
#define USE_MODULE_FHT8VSIMPLE_TX
#endif

#ifdef BOILER_HUB
; IF DEFINED: use RFM22 radio transceiver over SPI.
#define USE_MODULE_RFM22RADIOSIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
; IF DEFINED: use simple FHT8V RX code.
#define USE_MODULE_FHT8VSIMPLE_RX
#endif

#ifdef USE_MODULE_DS1306RTCSPISIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
#else
; IF DEFINED: in the absence of an RTC, and to keep sync with remote devices, keep on-chip elapsed time measure as good as possible.
#define KEEP_ELAPSED_TIME_ACCURATE ; Avoid any use of sleep, nap, etc, that stops or otherwise interferes with 'time' on 18M2+.
#define TIME_LSD_IS_BINARY ; Units of TIME_LSD is seconds wrapping at $ff (else will be BCD $00 to $59).
#endif




; B.1: Red 'calling for heat' LED and other UI.
symbol LED_HEATCALL = B.7
low LED_HEATCALL ; send low ASAP

; B.0: Direct DC active high output to call for heat, eg via SSR.
symbol OUT_HEATCALL = B.0
low OUT_HEATCALL ; send low ASAP


symbol SPI_SCLK_O = B.2          ; SPI clock (output) p8
symbol SPI_SDI = C.6             ; SPI data (input) C.6 18M2 p15
symbol SPI_SDI_PIN = input6      ; SPI data (input) in inputX format
symbol SPI_SDO = B.3             ; SPI data (output) 18M2 p9
symbol SPI_SDO_PIN = outpinB.3   ; SPI data (output) in outpinX.Y format.
symbol RFM22_nSEL_O = B.5; 18M2 p11
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
; B.6: DS1306 RTC active high Chip Enable for SPI
symbol DS1306_CE_O = B.6
low DS1306_CE_O ; make inactive ASAP
#endif


; B10 & B11 (aka W5)
; Temp/scratch bytes 0 & 1 and OVERLAID temp word 0.  Not expected to survive subroutine calls, etc.
symbol tempB0 = b10
symbol tempB1 = b11
symbol tempW0 = w5
; B12 & B13 (aka W6)
; Temp/scratch bytes 2 & 3 and OVERLAID temp word 1.  Not expected to survive subroutine calls, etc.
symbol tempB2 = b12
symbol tempB3 = b13
symbol tempW1 = w6

; W7 (aka B14 & B15)
; Current semi-random word value to help with anti-collision algorithms, etc.
; Will not contain much entropy, and may be updated only once per major cycle.
symbol randWord = w7
symbol randMSB = b14
symbol randLSB = b15

#ifdef USE_MODULE_SPISIMPLE
; B16
; SPI routines usually read/write byte to/from here.
symbol SPI_DATAB = b16
#endif

; B17
; Least-significant digits of time, as captured at start of each loop iteration.
; Units are seconds, and may be binary (#ifdef TIME_LSD_IS_BINARY) else BCD, typically depending whether an RTC is being used.
; In binary this runs from 0 to $ff (continuous), in BCD from 0 to $59 (discontinuous).
symbol TIME_LSD = b17

; B18 & B19 (aka W9)
symbol FHT8V_HC1 = 99; 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 99; 73 ; House code 2, constant or (byte) register.
;symbol FHT8V_ADR = 0 ; Sub-address, constant or (byte) register.  0 for broadcast and fixed as a constant here.
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).


; W11 (aka B22 & B23)
#ifdef BOILER_HUB
symbol boilerCountdown = W11 ; Decrements once per second if non-zero; while non-zero forces boiler call for heat.
symbol BOILER_CALL_TIMEOUT_S = 180 ; Time in seconds from last call for heat to boiler going off.  3 mins longer than FHT8V TX cycle + 1 minute.
#endif


; TX/RX scratchpad block...
symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area.
symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.

symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8: seq of (reg#,value) pairs term w/ $ff reg#.



high LED_HEATCALL

; Power-on minimal init.
gosub RFM22PowerOnInit

; Check that a RFM22 seems to be correctly connected.
gosub RFM22CheckConnected
if SPI_DATAB != 0 then panic

; Check that a RFM22 still seems to be correctly connected even when using a faster clock.
setfreq m16
gosub RFM22CheckConnected
if SPI_DATAB != 0 then panic
setfreq m4


; Standby mode.
gosub RFM22ModeStandby

; Test block setup of registers.
tempB0 = FHT8V_RFM22_Reg_Values
gosub RFM22RegisterBlockSetup

low LED_HEATCALL

#rem
sleep 4
; Register dump (omitting $7f, the RX FIFO).
gosub DiagHexDumpHeaderWithZeros
for tempB3 = 0 to $7e

    ; Insert dump line headers as necessary
    B0 = tempB3 & 15
    if B0 = 0 then
        if tempB3 != 0 then : sertxd(13,10) : endif
        B0 = tempB3 / 16
        gosub DiagSertxdHexByte
        sertxd(" :")
    endif

    SPI_DATAB = tempB3
    gosub RFM22ReadReg8Bit
    ;sertxd("Reg ",#tempB3," = ",#SPI_DATAB,13,10)
    sertxd(" ")
    B0 = SPI_DATAB
    gosub DiagSertxdHexByte
next
sertxd(13,10)
sleep 4
#endrem



; Main loop; never exits.
; Rough emulation of main loop from TRVControl.bas.
do



    ; DO NORMAL STUFF IN MAIN BODY OF LOOP




    ; Wait for elapsed time to roll...

    ;debug ; Can be a handy spot to inspect memory...

#ifdef BOILER_HUB ; Start listening for TRV nodes calling for heat.
    gosub SetupToEavesdropFHT8V

    if boilerCountdown > 0 then
        dec boilerCountdown
        high OUT_HEATCALL
    else
        low OUT_HEATCALL
    endif
#endif

    do
        ; Capture elapsed time (and wait for it to roll over).
        ; As soon as the elapsed time rolls over, start new main loop.
        ; In the interim, fill time with radio RX and/or energy saving sleeps and/or random number churn, ...
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
        gosub DS1306ReadBCDSeconds
        tempB0 = SPI_DATAB ; BCD seconds.
#else
        tempB0 = time ; Internal elapsed time measure least-significant byte (binary).
#endif
        if tempB0 != TIME_LSD then
            ; TODO if (masked) time rolls to a smaller number then trigger the minute counter; robust even if individual seconds get missed.
            TIME_LSD = tempB0
            exit
        endif


#ifdef BOILER_HUB ; Stop listening for TRV nodes calling for heat.
        ; Listen/RX radio comms if appropriate.
        if boilerCountdown != BOILER_CALL_TIMEOUT_S then ; Skip listening if just heard RX.
            gosub RFM22ReadStatusBoth
            if SPI_DATAB >= $80 then ; Got sync from incoming FHT8V message.
    
                ; Force boiler on for a while...
                boilerCountdown = BOILER_CALL_TIMEOUT_S
    
                high LED_HEATCALL
                nap 0
                low LED_HEATCALL
    
                ; Stop listening so as to save energy.
                gosub RFM22ModeStandbyAndClearState
    
            else if tempB2 >= $80 then ; RX FIFO overflow/underflow: give up and restart...
                gosub SetupToEavesdropFHT8V ; Restart listening...
            endif
        endif
#endif


        ; Churn the random value to fill time and make it more randomy...  B^>
        random randWord

        ; Sleep/pause a little, saving energy if possible.
        ; May be able to sleep in longer chunks if NOT doing radio RX and NOT yet at half-second mark...
#ifdef KEEP_ELAPSED_TIME_ACCURATE
        pause 18
#else
        disablebod
        nap 0
        enablebod
#endif
    loop

#ifdef BOILER_HUB ; Stop listening for TRV nodes calling for heat.
    gosub setHighClockSpeed
    gosub RFM22ModeStandbyAndClearState ; Known state, FIFOs cleared, standby mode.
    gosub setNormalClockSpeed
#endif
loop ; end of main loop

end


#ifdef BOILER_HUB ; Set up radio to listen for TRV nodes calling for heat.
SetupToEavesdropFHT8V:
    gosub setHighClockSpeed

    ; Clear RX and TX FIFOs.
    SPI_DATAB = $8 ; RFM22REG_OP_CTRL2
    tempB2 = 3 ; FFCLRRX | FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = $8; RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0

    ; Set FIFO RX almost-full threshold.
    SPI_DATAB = $7e ; RFM22REG_RX_FIFO_CTRL
    tempB2 = 34 ; Less than shortest valid FHT8V frame...
    gosub RFM22WriteReg8Bit

    ; Enable just the RX sync-detect interrupt.
    SPI_DATAB = 5 ; RFM22REG_INT_ENABLE_1
    gosub RFM22WriteReg8Bit0
    SPI_DATAB = 6 ; RFM22REG_INT_ENABLE_2
    tempB2 = $80
    gosub RFM22WriteReg8Bit

    gosub RFM22ClearInterrupts ; Clear any current status.
    gosub RFM22ModeRX ; Start listening...

    gosub setNormalClockSpeed
    return
#endif







; PANIC
; In case of hardware not working correctly stop doing anything difficult/dangerous
; while indicating distress to users and conserving power if possible.
panic:
    B0 = $ff
    do
        high LED_HEATCALL
        nap 0
        low LED_HEATCALL
        nap 3
    loop
    end


; Set the default clock speed (with correct elapsed-time 'time' behaviour).
setNormalClockSpeed:
    setfreq m4
    return

; Set a high clock speed (that preserves the elapsed-time 'time' behaviour if KEEP_ELAPSED_TIME_ACCURATE).
; http://www.picaxe.com/BASIC-Commands/Advanced-PICAXE-Configuration/enabletime/
setHighClockSpeed:
    setfreq m16 ; As fast as possible while maintaining elapsed 'time' word correctly on 18M2+ and works down to minimum supply voltage.
    return



#rem
getFrame:
    ; Burst read from FIFO into memory...
    setfreq m32
    low RFM22_nSEL_O
    SPI_DATAB = $7f
    gosub SPI_shiftout_byte_MSB_preclock
    for tempB3 = ScratchMemBlock to ScratchMemBlockEnd
        gosub SPI_shiftin_byte_MSB_preclock
        poke tempB3, SPI_DATAB
    next
    high RFM22_nSEL_O
    setfreq m4
    return

dumpFrame:
    sertxd("Frame: ");
    for tempB3 = ScratchMemBlock to ScratchMemBlockEnd
        peek tempB3, tempB0
        sertxd(#tempB0,", ");
    next
    sertxd(13,10)
    return
#endrem
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** DS1306-RTC-SPI-simple.inc.bas ****** in module library
; Basic support for DS1306 2V--5V RTC in SPI mode.
; Appendable PICAXE basic fragment.



; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol DS1306_CE_O ; output bit


#rem
Typical hardware setup, eg with supercap, using 16-pin DIL version.

VCC1 (p16), VCCIF (p14) -> V+ (2V--5V)
VBAT (p2) -> 0V
VCC2 (p1) -> 0V (or to supercap +ve to trickle charge)
GND (p8) -> 0V
SERMODE (p9) -> V+ (to select SPI mode)
X1&X2 (p3&p4) -> crystal

Connections to PICAXE:
SDO
SDI
SCLK
CE (B.6/p12, high to enable/select, has internal 55k pulldown)
#endrem



#ifdef USE_MODULE_DS1306RTCSPISIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_DS1306RTCSPISIMPLE ; Prevent duplicate use...

; Reads the seconds register (in BCD, from $00 to $59) into SPI_DATAB.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSeconds:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclock
    low DS1306_CE_O
    return

#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** FHT8V-simple.inc.bas ****** in module library
; Basic support for FHT8V wireless electronic TRV over RFM22B radio.
; Appendable PICAXE basic fragment.
; TX and RX elements can be enabled separately to preserve code space.

; Many thanks to Mike Stirling http://mikestirling.co.uk/2012/10/hacking-wireless-radiator-valves-with-gnuradio/
; for register settings, the 200us encoding, and lots of hand-holding!

; RECENT CHANGES
; DHD20130225: created separate FHT8VQueueCmdViaRFM22Bptr routine to allow generation to be separated from TX.
; DHD20130224: added 0xff postamble to transmitted frame to be easier to capture by RFM22/PICAXE.
; DHD20130224: creating FHT8VCreate200usBitStreamBptr with bptr base to allow possibility of cacheing, etc.
; DHD20130223: using 0xaacccccc RX sync word (end of RFM22 pre-preamble and start of FHT preamble) for robustness.
; DHD20130223: turned down transmission power: may have to make setting conditional on whether RFM23 is being used instead.


; Dependencies (for USE_MODULE_FHT8VSIMPLE_TX, transmit side, no I/O)
; symbol FHT8V_HC1 ; House code 1, constant or (byte) register.
; symbol FHT8V_HC2 ; House code 2, constant or (byte) register.
; #define FHT8V_ADR_USED (optional) ; If true then FHT8V_ADR used, else assumed 0 (multicast).
; symbol FHT8V_ADR (optional) ; Sub-address, constant or (byte) register.
; symbol FHT8V_CMD ; Constant or (usually) command byte register.
; symbol FHT8V_EXT ; Constant or (usually) command extension byte register.
; panic: ; Label for any routine to jump to to abort system operation as safely as possible.
; symbol FHT8V_RFM22_Reg_Values ; start address in EEPROM for register setup values.
; #define DEBUG (optional) ; enables extra checking, eg during unit tests.
; #define RFM22_IS_ACTUALLY_RFM23 (optional) ; indicates that RFM23B module is being used in place of RFM22B.
; #define USE_MODULE_RFM22RADIOSIMPLE (optional) ; to include some specific RFM22 support.





#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use content if explicitly requested.
#define USE_MODULE_FHT8VSIMPLE_REG ; Enable placement of register settings in EEPROM.
#endif
#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use content if explicitly requested.
#define USE_MODULE_FHT8VSIMPLE_REG ; Enable placement of register settings in EEPROM.
#endif


#ifdef USE_MODULE_FHT8VSIMPLE_REG
; Register setup for FHT8V TX over RFM22B radio.
; Setup data for the RFM22 and FHT8V.
; Consists of a sequence of (reg#,value) pairs terminated with a $ff register number.  The reg#s are <128, ie top bit clear.
; Magic numbers c/o Mike Stirling!
EEPROM FHT8V_RFM22_Reg_Values, ($6,0) ; Disable default chiprdy and por interrupts.
; EEPROM ($8,0) ; RFM22REG_OP_CTRL2: ANTDIVxxx, RXMPK, AUTOTX, ENLDM
#ifndef RFM22_IS_ACTUALLY_RFM23
; For RFM22 with RXANT tied to GPIO0, and TXANT tied to GPIO1...
EEPROM ($b,$15, $c,$12) ; DISABLE FOR RFM23
#endif
; 0x30 = 0x00 - turn off packet handling
; 0x33 = 0x06 - set 4 byte sync
; 0x34 = 0x08 - set 4 byte preamble
; 0x35 = 0x10 - set preamble threshold (RX) 2 nybbles / 1 bytes of preamble.
; 0x36-0x39 = 0xaacccccc - set sync word, using end of RFM22-pre-preamble and start of FHT8V preamble.
EEPROM ($30,0, $33,6, $34,8, $35,$10, $36,$aa, $37,$cc, $38,$cc, $39,$cc)
; From AN440: The output power is configurable from +13 dBm to Ð8 dBm (Si4430/31), and from +20 dBM to Ð1 dBM (Si4432) in ~3 dB steps. txpow[2:0]=000 corresponds to min output power, while txpow[2:0]=111 corresponds to max output power.
; The maximum legal ERP (not TX output power) on 868.35 MHz is 25 mW with a 1% duty cycle (see IR2030/1/16).
;EEPROM ($6d,%00001111) ; RFM22REG_TX_POWER: Maximum TX power: 100mW for RFM22?  May not be legal in UK on RFM22.
EEPROM ($6d,%00001011) ; RFM22REG_TX_POWER: Somewhat above minimum TX power.
;EEPROM ($6d,%00001000) ; RFM22REG_TX_POWER: Minimum TX power (-1dBm).
EEPROM ($6e,40, $6f,245) ; 5000bps, ie 200us/bit for FHT (6 for 1, 4 for 0).  10485 split across the registers, MSB first.
EEPROM ($70,$20) ; MOD CTRL 1: low bit rate (<30kbps), no Manchester encoding, no whitening.
EEPROM ($71,$21) ; MOD CTRL 2: OOK modulation.
EEPROM ($72,$20) ; Deviation GFSK. ; WAS EEPROM ($72,8) ; Deviation 5 kHz GFSK.
EEPROM ($73,0, $74,0) ; Frequency offset
; Channel 0 frequency = 868 MHz, 10 kHz channel steps, high band.
EEPROM ($75,$73, $76,100, $77,0) ; BAND_SELECT,FB(hz), CARRIER_FREQ0&CARRIER_FREQ1,FC(hz) where hz=868MHz
EEPROM ($79,35) ; 868.35 MHz - FHT
EEPROM ($7a,1) ; One 10kHz channel step.
; RX-only
#ifdef USE_MODULE_FHT8VSIMPLE_RX ; RX-specific settings, again c/o Mike S.
EEPROM ($1c,0xc1, $1d,0x40, $1e,0x0a, $1f,0x03, $20,0x96, $21,0x00, $22,0xda, $23,0x74, $24,0x00, $25,0xdc) ; 0$1c was 0xc1
EEPROM ($2a,0x24)
EEPROM ($2c,0x28, $2d,0xfa, $2e,0x29)
EEPROM ($69,$60) ; AGC enable: SGIN | AGCEN
#endif
; Terminate the initialisation data.
EEPROM ($ff,$ff)
#rem ; Sample control register dump (from RFM23B) by Mike S 20130221 including RX values, for reference:
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 CC CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0F 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37
#endrem

#rem ; DHD20130226 dump and diff ms dhd
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 AA CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0B 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37

5c5
< 03 : 00 00 0C 06 08 10 CC CC CC CC 00 00 00 00 00 00
---
> 03 : 00 00 0C 06 08 10 AA CC CC CC 00 00 00 00 00 00
8c8
< 06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0F 28 F5
---
> 06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0B 28 F5
#endrem
#endif



#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use TX support content if explicitly requested.
#undefine USE_MODULE_FHT8VSIMPLE_TX ; Prevent duplicate use...


#ifdef USE_MODULE_RFM22RADIOSIMPLE ; RFM22 module must be loaded to use this.
; Clears the RFM22 TX FIFO and queues up ready to send via RFM22TXFIFO the $ff-terminated FHT8V command starting at bptr.
; The FHT8V frame may have been previously generated with FHT8VCreate200usBitStream.
; B0, bptr, tempB1 are destroyed.
; This routine does a lot of I/O and can be run at a high clock speed to help bit-band faster.
; This routine does not change the command area or FHT_XXX values.
FHT8VQueueCmdViaRFM22Bptr:
    ; Clear the TX FIFO.
    gosub RFM22ClearTXFIFO
    ; Load bit stream (and preambles) into RFM22 using burst-write mode...
    low RFM22_nSEL_O
    B0 = $ff ; TX FIFO (burst) write to register $7f.
    gosub SPI_shiftout_byte_MSB_preclB0
#rem
    ; RFM22B-friendly pre-preamble of 4 x 0xAA.
    B0 = $aa
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
#endrem
    ; Send out FHT8V encoded frame.
    do
        B0 = @bptrinc
        if B0 = $ff then exit
        gosub SPI_shiftout_byte_MSB_preclB0
    loop
    high RFM22_nSEL_O
    return
#endif


; Create stream of bytes to be transmitted to FHT80V at 200us per bit, msbit of each byte first.
;
; Byte stream is terminated by $ff byte which is not a possible valid encoding.
; On entry, FHT8V_HC1, FHT8V_HC2, FHT8V_ADR (0 if undefined), FHT8V_CMD and FHT8V_EXT are inputs (and not destroyed if registers).
; On exit, the memory block starting at ScratchMemBlock contains the low-byte, msbit-first bit, $ff terminated TX sequence.
; The maximum and minimum possible encoded message sizes are 35 (all zero bytes) and 45 (all $ff bytes) bytes long.
; Note that a buffer space of at least 46 bytes is needed to accommodate the longest message and the terminator.
; B0, tempB1 are destroyed.
; bptr is pointing to the terminating $ff on exit.
FHT8VCreate200usBitStreamBptr:
    ; Generate preamble.
    ; First 12x 0 bits of preamble, pre-encoded.
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptr = $ff ; Initialise for _FHT8VCreate200usAppendEncBit routine.
    ; Push remaining 1 of preamble.
    Bit7 = 1
    gosub _FHT8VCreate200usAppendEncBit
;sertxd("H");

    ; Generate body.
    B0 = FHT8V_HC1
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_HC2
    gosub _FHT8VCreate200usAppendByteEP
#ifdef FHT8V_ADR_USED
    B0 = FHT8V_ADR
#else
    B0 = 0 ; Default/broadcast.  TODO: could possibly be further optimised to send 0 value more efficiently.
#endif
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_CMD
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_EXT
    gosub _FHT8VCreate200usAppendByteEP
    ; Generate checksum.
#ifdef FHT8V_ADR_USED
    B0 = $c + FHT8V_HC1 + FHT8V_HC2 + FHT8V_ADR + FHT8V_CMD + FHT8V_EXT
#else
    B0 = $c + FHT8V_HC1 + FHT8V_HC2 + FHT8V_CMD + FHT8V_EXT
#endif
    gosub _FHT8VCreate200usAppendByteEP

    ; Generate trailer.
;sertxd("T");
    ; Append 0 bit for trailer.
    Bit7 = 0
    gosub _FHT8VCreate200usAppendEncBit
    ; Append extra 0 bit to ensure that final required bits are flushed out.
    ;Bit7 = 0
    gosub _FHT8VCreate200usAppendEncBit

    @bptr = $ff ; Terminate TX bytes.
;sertxd(13,10);
    return

; Appends encoded 200us-bit representation of logical msbit from B0.
; If the most significant bit of B0 (Bit7) is 0 this appends 1100 else this appends 111000
; msb-first to the byte stream being created by FHT8VCreate200usBitStream.
; Does NOT destroy B0.
; bptr must be pointing at the current byte to update on entry which must start off as $ff;
; this will write the byte and increment tempB0 (and write $ff to the new location) if one is filled up.
; Partial byte can only have even number of bits present, ie be in one of 4 states.
; Two least significant bits used to indicate how many bit pairs are still to be filled,
; so initial $ff value (which is never a valid complete filled byte) indicates 'empty'.
; Destroys tempB1.
_FHT8VCreate200usAppendEncBit:
;sertxd(#bit7);
    tempB1 = @bptr & 3 ; Find out how many bit pairs are left to fill in the current byte.
    if bit7 = 0 then ; Appending 1100
        select case tempB1
            case 3 ; Empty target byte (should be $ff currently).
                @bptr = %11001101 ; Write back partial byte (msbits now 1100 and two bit pairs remain free).
            case 2 ; Top bit pair already filled.
                @bptr    = @bptr & %11000000 | %110000 ; Preserve existing ms bit-pair, set middle four bits 1100, one bit pair remains free.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1100 ; Preserve existing ms bit-pairs, set bottom four bits 1100, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            else ; Top three bit pairs already filled.
                @bptrinc = @bptr & %11111100 |     %11 ; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
        endselect
    else ; Appending 111000
        select case tempB1
            case 3 ; Empty target byte (should be $ff currently).
                @bptr = %11100000 ; (one bit pair remains free)
            case 2 ; Top bit pair already filled.
                @bptrinc = @bptr & %11000000 | %111000 ; Preserve existing ms bit-pair, set lsbits to 111000, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1110; Preserve existing ms bit-pairs, set bottom four bits to 1110, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
            else ; Top three bit pairs already filled.
                @bptrinc = @bptr & %11111100 |     %11; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptr = %10001101 ; Write trailing 1000 bits to next byte and indicate 2 bit-pairs free for next incremental update.
        endselect
    endif
    return

; Appends byte in B0 msbit first plus trailing even parity bit (9 bits total)
; to the byte stream being created by FHT8VCreate200usBitStream.
; Destroys B0.
_FHT8VCreate200usAppendByteEP:
;sertxd("-");
    ; Send the byte msbit first while building the parity bit in bit 0.
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 7.
    if bit7 = 0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 6.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 5.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 4.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 3.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 2.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 1.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 0.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    bit7 = bit0 ; Computed parity is in bit 0...
    ;GOSUB CHAIN: GOSUB _FHT8VCREATE200USAPPENDENCBIT RETURN ; FOR SPEED AND TO PRESERVE GOSUB SLOTS/
    GOTO _FHT8VCREATE200USAPPENDENCBIT
    goto _FHT8VCreate200usAppendEncBit ; GOSUB CHAIN: gosub _FHT8VCreate200usAppendEncBit return ; For speed and to preserve gosub slots.

#endif USE_MODULE_FHT8VSIMPLE_TX




#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use RX support content if explicitly requested.
#undefine USE_MODULE_FHT8VSIMPLE_RX ; Prevent duplicate use...



#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** LDROccupancyDetection.inc.bas ****** in module library
; Simple occupancy detection using ambient light levels.
; Appendable PICAXE basic fragment.

; RECENT CHANGES
; DHD20130225: Changed global this sets to "isRoomLit" and also uses it to provide hysteresis.
; DHD20130221: Bumped threshold up a little to 33 (~13%) based on observations.


; Dependencies:
; INPUT_LDR ADC input pin symbol must be defined with LDR to +V and pull-down to 0V (so more light gives higher value).
; isRoomLit bit symbol must be defined; will be set to 1 if room is light enough for occupancy/activity, 0 otherwise.
; tempB0 temporary byte symbol must be defined; will be used/overwritten.

; Using techsupplies.co.uk SEN002 (like GL5528 1M+ dark, ~10k @ 10 Lux) with fixed pull-down resistor.
; Works OK with 10k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (5V) at threshold of 25 (~10% max).
; Works OK with 100k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (3.3V) at threshold of 25 (~10% max).  ("Dark" at night ~5.)



#ifdef USE_MODULE_LDROCCUPANCYDETECTION ; Only use content if explicitly requested.
#undefine USE_MODULE_LDROCCUPANCYDETECTION ; Prevent duplicate use...




; Attempts to detect potential room use/occupancy from ambient light levels: sets isRoomLit if light enough to be in use.
; Leaves current light level in tempB0 (255 is maximum light level, 0 is fully dark).
getRoomInUseFromLDR:
    ; Check light levels, setting isRoomLit 1 if light enough for activity in the room else 0, with some hysteresis.
    ; The system can use ambient light level to help guess occupancy; very dark (<13% of max) implies no active occupants.
    readadc INPUT_LDR, tempB0
    if tempB0 < 30 then
        isRoomLit = 0
    else if tempB0 > 35 then
        isRoomLit = 1
    endif
    return





#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** RFM22B-radio-simple.inc.bas ****** in module library
; Basic support for RFM22B (or RFM23B) radio transceivers in SPI mode (si443x chipset), and no use of interrupts.
; Appendable PICAXE basic fragment.

; Many thanks to Mike Stirling http://mikestirling.co.uk/2012/10/hacking-wireless-radiator-valves-with-gnuradio/
; for register settings, the 200us encoding, and lots of hand-holding!

; RECENT CHANGES:
; DHD20130224: testing 'gosub chaining' at tail of subroutines to save gosub slots and possible some time/space.
; DHD20130222: using pause and loop limit in RFM22TXFIFO to avoid lockup in that routine (bashing on SPI too hard) and save some juice?
; DHD20130222: using RFM22ModeStandbyAndClearState at end of init and TXFIFO routines in hope of reducing power consumption (turning interrupts off).

; TODO: see note at end on suggestions for self-check and reset.


; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol RFM22_nSEL_O ; output bit, low to select/enable RFM22.
; #define RFM22_nIRQ_I (optional) ; input bit, low to indicate interrupt from RFM22: without this software polling will be used.
; #define symbol RFM22_nIRQ_I_PIN (optional) ; inputX version of RFM22_nIRL_I.  Must be defined iff RFM22_nIRQ_I is.
; #define KEEP_ELAPSED_TIME_ACCURATE (optional) ; avoid nap/sleep etc if defined, and use pause instead.

; For receive:
; symbol ScratchMemBlock ; Start of contiguous scratch memory area (to RX FIFO data into) < 0x100.
; symbol ScratchMemBlockEnd ; Inclusive end of scratch memory area, > ScratchMemBlock and < 0x100.




#ifdef USE_MODULE_RFM22RADIOSIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_RFM22RADIOSIMPLE ; Prevent duplicate use...

; See Hope RF RFM22/RFM23 data sheet for register and value definitions.
symbol RFM22REG_INT_STATUS1 = $03 ; Interrupt status register 1.
symbol RFM22REG_INT_STATUS2 = $04 ; Interrupt status register 2.
symbol RFM22REG_INT_ENABLE1 = $05 ; Interrupt enable register 1.
symbol RFM22REG_INT_ENABLE2 = $06 ; Interrupt enable register 2.
symbol RFM22REG_OP_CTRL1 = $07 ; Operation and control register 1.
symbol RFM22REG_OP_CTRL1_SWRES = $80 ; Software reset (at write) in OP_CTRL1.
symbol RFM22REG_OP_CTRL2 = $08 ; Operation and control register 2.
symbol RFM22REG_TX_POWER = $6d ; Transmit power.
symbol RFM22REG_FIFO = $7f ; Transmit FIFO on write.
; Allow validation of RFM22/FRM23 device and SPI connection to it.
symbol RFM22_SUPPORTED_DEVICE_TYPE = 0x08 ; Read from register 0.
symbol RFM22_SUPPORTED_DEVICE_VERSION = 0x06 ; Read from register 1.


; Minimal set-up of I/O (etc) after system power-up.
; Perform a software reset and leave the radio deselected and in a low-power and safe state.
; Destroys some or all of tempB0, tempB1, tempB2, B0 and SPI_DATAB.
RFM22PowerOnInit:
    ; Make sure nSEL set as output and RFM22 deselected ASAP.
    high RFM22_nSEL_O
    ; Warm up SPI.
    gosub SPI_init
    ; Software reset.
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = RFM22REG_OP_CTRL1_SWRES
    gosub RFM22WriteReg8Bit
    ; TODO : wait for nIRQ to fall if pin defined.
    ; Drop into minimal-power standby mode with interrupts off, etc.
    ;gosub RFM22ModeStandbyAndClearState
    gosub RFM22ModeStandby
    return

; Simple test that RFM22 seems to be correctly connected over SPI.
; Returns 0 in SPI_DATAB if RFM22 appears present and correct, else non-zero value for something wrong.
; Can be called before or after RFM22PowerOnInit.
RFM22CheckConnected:
    SPI_DATAB = 0 ; device type
    gosub RFM22ReadReg8Bit
    if SPI_DATAB != RFM22_SUPPORTED_DEVICE_TYPE then _RFM22CheckConnectedError
    SPI_DATAB = 1 ; device version
    gosub RFM22ReadReg8Bit
    if SPI_DATAB != RFM22_SUPPORTED_DEVICE_VERSION then _RFM22CheckConnectedError
    SPI_DATAB = 0 ; All OK.
    return
; Error return.
_RFM22CheckConnectedError:
    SPI_DATAB = 1 ; Error value
    return

; Set up a block of RFM22 registers from EEPROM (for efficiency/clarity).
; Pass the starting address in EEPROM as tempB0.
; EEPROM data is a sequence of (reg#,value) pairs terminated with a $ff register.  The reg#s are <128, ie top bit clear.
; Destroys tempB0, tempB2, SPI_DATAB
RFM22RegisterBlockSetup:
    do
        read tempB0, SPI_DATAB, tempB2
        if SPI_DATAB > 127 then exit
        gosub RFM22WriteReg8Bit ; Must not destroy tempB0.
        tempB0 = tempB0 + 2
    loop
    return


; Read status (both registers) and clear interrupts.
; Status register 1 is returned in tempB2: 0 indicates no pending interrupts or other status flags set.
; Status register 2 is returned in SPI_DATAB: 0 indicates no pending interrupts or other status flags set.
; Destroys B0 and tempB0.
RFM22ReadStatusBoth:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    tempB2 = SPI_DATAB
    gosub SPI_shiftin_byte_MSB_preclock
    high RFM22_nSEL_O
    return

; Read/discard status (both registers) to clear interrupts.
; Destroys SPI_DATAB, B0 and tempB0.
RFM22ClearInterrupts:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    ;gosub SPI_shiftin_byte_MSB_preclock
    ;gosub SPI_shiftin_byte_MSB_preclock
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    return


; Enter standby mode and clear FIFOs, status, etc.
; May be necessary to achieve lowest power consumption.
; Destroys SPI_DATAB, tempB2, B0.
; FIXME: far too slow
RFM22ModeStandbyAndClearState:
    ; Go into standby mode (inlined RFM22ModeStandby subroutine).
    SPI_DATAB = RFM22REG_OP_CTRL1
    gosub RFM22WriteReg8Bit0
    ; Clear RX and TX FIFOs.
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 3 ; FFCLRRX | FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0
    ; Clear any pending interrupts.  FIXME: may need to be done after disabling ints to avoid races?
    gosub RFM22ClearInterrupts
    ; Disable all interrupts.  (May help radio power down fully.)
    SPI_DATAB = RFM22REG_INT_ENABLE1
    gosub RFM22WriteReg8Bit0
    SPI_DATAB = RFM22REG_INT_ENABLE2
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.

#rem
; Clear RX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearRXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 2 ; FFCLRRX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.
#endrem

; Clear TX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearTXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 1 ; FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.

; Enter standby mode (consume least possible power but retain register contents).
; Destroys SPI_DATAB, B0.
RFM22ModeStandby:
    SPI_DATAB = RFM22REG_OP_CTRL1
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.

; Enter 'tune' mode (to enable fast transition to TX or RX mode).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTune:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000010 ; PLLON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

; Enter transmit mode (and send any packet queued up in the TX FIFO).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00001001 ; TXON | XTON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

; Enter receive mode.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeRX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000101 ; RXON | XTON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

; Append a single byte to the transmit FIFO.
; Does not check for or prevent overflow.
; Byte to write should be in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteByteToTXFIFO:
    SPI_DATAB = RFM22REG_FIFO
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

; Transmit contents of on-chip TX FIFO: caller should revert to low-power standby mode (etc) if required.
; Destroys tempB0, tempB1, tempB2, B0, SPI_DATAB.
; Note: Reliability possibly helped by early move to 'tune' mode to work other than with default (4MHz) lowish PICAXE clock speeds.
; FIXME: still unreliable if > 8MHz from about "gosub RFM22ModeTX" onwards.  This may be more the RFM22B's problem than the PICAXE's.
RFM22TXFIFO:
    gosub RFM22ModeTune ; Warm up the PLL for quick transition to TX below (and ensure NOT in TX mode).
    ; Enable interrupt on packet send ONLY.
    SPI_DATAB = RFM22REG_INT_ENABLE1
    tempB2 = 4
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_INT_ENABLE2
    gosub RFM22WriteReg8Bit0
    gosub RFM22ClearInterrupts ; Clear any current status...
    gosub RFM22ModeTX ; Enable TX mode and transmit TX FIFO contents.

; FIXME: setfreq m8 ; NEEDED HERE TO BE RELIABLE

    ; Whole TX likely to take > 60ms for a typical message; avoid bashing SPI too hard!
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    for tempB1 = 0 to 32 ; Should be plenty of time even at max clock rate...
        pause 18 ; May be a fraction of nominal pause time if running at high clock speed.
#else
    for tempB1 = 0 to 8 ; Should be plenty of time even with some wobble on nap timer...
        nap 0 ; Save a little energy...
#endif
        gosub RFM22ReadStatusBoth
        if tempB2 != 0 then exit ; Packet sent...
    next tempB1 ; Spin until packet sent...  COULD POLL INPUT PIN FROM nIRQ FIRST/INSTEAD.
    ; TODO: possible retransmit after few (randomised?) ms gap for improved reliability?
    ;gosub RFM22ModeStandbyAndClearState ; Back to low-power standby mode.
    return

#rem
; Receive in FIFO mode to scratch memory area ScratchMemBlock.
; Maximum length of message that can be received is limited to the scratch area size.
RFM22RXFIFO:
    gosub RFM22ModeStandbyAndClearState ; Known state, FIFOs cleared, standby mode.

    ; Enable sync-detect interrupt

    ; TODO

    return
#endrem


; Reads a byte from a radio register over SPI.
; Register number in SPI_DATAB on call (with msb / bit 7 = 0 for read).
; Result is returned in SPI_DATAB.
; Destroys tempB0, B0.
RFM22ReadReg8Bit:
    low RFM22_nSEL_O
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    high RFM22_nSEL_O
    return

; Writes a byte to a radio register over SPI.
; Register number in SPI_DATAB on call (will be destroyed); $80 is ORed in to enforce write mode.
; Data content to write in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit:
    low RFM22_nSEL_O
    B0 = SPI_DATAB | $80
    gosub SPI_shiftout_byte_MSB_preclB0
    B0 = tempB2
    gosub SPI_shiftout_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a zero byte to a radio register over SPI.  (Optimised common case.)
; Register number in SPI_DATAB on call (will be destroyed); $80 is ORed in to enforce write mode.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit0:
    low RFM22_nSEL_O
    B0 = SPI_DATAB | $80
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    return


#endif





#rem
TODO: run-time health-check and reset (or panic)

See: http://www.picaxeforum.co.uk/showthread.php?23347-18M2-unreliable-at-32MHz-%28m32%29-at-3-3V&p=231717&viewfull=1#post231717

DHD20130223: Interesting thought on the RFM22 resetting itself. How would you (quickly) check in this instance if such a reset had happened so the config could be re-applied?

srnet:

There is a POR flag bit that should be set, but I found it more reliable to check if the 3 main frequency setting registers have changed away from their configured settings.

Which also serves another purpose, you can check that you are actually transmitting on the frequency you should be.

There are also circumstances where if there is enough RF power fed back into the circuit, the Si4432 (the microcontroller on the RFM22) has its brains scrambled completely, the registers go haywire. The only recovery is a shutdown of the device, so dont just ground the SDN pin, control it with a PICAXE pin so you can force a RFM22 reset. 
#endrem
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** SPISimple.inc.bas ****** in module library
; Basic support for SPI I/O.
; Appendable PICAXE basic fragment.



; Dependencies:
; Must already be declared
;symbol SPI_SCLK_O (pin)         ; SPI clock (output)
;symbol SPI_SDI (pin)            ; SPI data (input) to device SDO (may need weak h/w pull-up)
;symbol SPI_SDI_PIN (inpin)      ; SPI data (input) in inputX format
;symbol SPI_SDO (pin)            ; SPI data (output) to device SDI
;symbol SPI_SDO_PIN (outpin)     ; SPI data (output) in outpinX.Y format: ***must be set to output!***
;symbol SPI_DATAB (byte)         ; SPI write byte from here and read byte to here
;symbol tempB0 (byte)            ; temp working variable
;symbol tempB1 (byte)            ; temp working variable


#ifdef USE_MODULE_SPISIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_SPISIMPLE ; Prevent duplicate use...


; Units to 'pulseout' SPI_SCLK_O ; 10us units at normal clock but less at higher clock speeds
; Less than 10us seems unreliable, so use something >= 4 to allow for 4x--8x normal clock speed.
symbol SPI_PULSEOUT_UNITS = 8 ; 10us at 8x clock, 20us at 4x clock, 80us at normal clock.


; SPI initialisation.
; Mainly makes sure that inputs and outputs are pointing in the right direction.
SPI_init:
    output SPI_SCLK_O, SPI_SDO
    input SPI_SDI
    return


; SPI shift in (ie read) a single byte, most-significant bit first, data pre-clock.
; Returns input data in SPI_DATAB byte variable.
; Destroys tempB0.
SPI_shiftin_byte_MSB_preclock:
    SPI_DATAB = 0
    for tempB0 = 0 to 7
        SPI_DATAB = SPI_DATAB + SPI_DATAB    ; shift left as MSB first
        if SPI_SDI_PIN != 0 then
            SPI_DATAB = SPI_DATAB + 1       ; set LSB if SDI (incoming bit) == 1
        end if
        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS    
    next tempB0
    return

; SPI shift in (ie read) a single byte, most-significant bit first, data post-clock.
; Returns input data in SPI_DATAB byte variable.
; Destroys tempB0.
SPI_shiftin_byte_MSB_postclock:
    SPI_DATAB = 0
    for tempB0 = 0 to 7
        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS    
        SPI_DATAB = SPI_DATAB + SPI_DATAB    ; shift left as MSB first
        if SPI_SDI_PIN != 0 then
            SPI_DATAB = SPI_DATAB + 1       ; set LSB if SDI (incoming bit) == 1
        end if
    next tempB0
    return

#rem
; SPI shift out (ie write) a single byte, most-significant bit first, data pre-clock.
; Sends output data from SPI_DATAB byte variable.
; Destroys tempB0, tempB1, SPI_DATAB.
;SPI_shiftout_byte_MSB_preclock:
;    for tempB0 = 0 to 7
;        tempB1 = SPI_DATAB & $80
;        if tempB1 = 0 then
;            low SPI_SDO
;        else
;            high SPI_SDO
;        end if
;        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
;        SPI_DATAB = SPI_DATAB + SPI_DATAB
;    next tempB0
;    return
#endrem

; SPI shift out (ie write) a single byte, most-significant bit first, data pre-clock.
; Sends output data from SPI_DATAB byte variable.
; Destroys B0 only.
; Unrolled for speed and to reduce the working memory required: a few bytes larger than loop version...
;
; SPI_SDO_PIN must be an 'output' and set to output, see: http://www.picaxeforum.co.uk/showthread.php?23186-Bit-banging-head-banging
SPI_shiftout_byte_MSB_preclock:
    B0 = SPI_DATAB
SPI_shiftout_byte_MSB_preclB0: ; As for SPI_shiftout_byte_MSB_preclock but sends B0 rather than SPI_DATAB and does not destroy B0 (nor SPI_DATAB).
    SPI_SDO_PIN = bit7
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit6
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit5
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit4
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit3
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit2
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit1
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit0
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return

; SPI shift out (ie write) a single zero byte, most-significant bit first, data pre-clock.
; This is as fast as is reasonably possible, with unrolled code, etc.
SPI_shiftout_0byte_MSB_pre:
    low SPI_SDO
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return


#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** X10TXSimple.inc.bas ****** in module library
; Simple software-timed / bit-banging X10 RF transmit.
; Appendable PICAXE basic fragment.



; Dependencies:
; X10WordOut word symbol must be defined.

#ifdef USE_MODULE_X10TXSIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_X10TXSIMPLE ; Prevent duplicate use...


; Sends X10WordOut; content of work may be destroyed.
; Based on J C Burchell version 1.0 2009 code at https://docs.google.com/document/pub?id=1dF5rpRkv-Ty3WcXs8D9Oze86hR50ZI96RzNrMvd_S0U
; Runs overspeed to meet timing constraints.
X10Send:

	; TODO

    return




#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** diagtools.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; Diagnostic tools, useful for development and debugging.

#ifdef USE_MODULE_DIAGTOOLS ; Only use content if explicitly requested.
#undefine USE_MODULE_DIAGTOOLS ; Prevent duplicate use...



; Dump byte in B0 (not altered) as two digit hex to serial.
; B1 is destroyed.
DiagSertxdHexByte:
  B1 = B0 / 16 + "0" ; High nybble.
  gosub _DiagSertxdHexNybble
  B1 = B0 & 15 + "0" ; Low nybble.
_DiagSertxdHexNybble:
  if B1 > "9" then
      B1 = B1 + 7
  endif
  sertxd(B1)
  return


#rem
Target is to be able to make a hex dump which looks like:
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 CC CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0F 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37
#endrem

; Output dump table header of form "     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F" (note 5 leading spaces).
; B0, B1 are destroyed.
DiagHexDumpHeaderWithZeros:
    sertxd("    ");
    for B0 = 0 to 15
        sertxd(" ");
        gosub DiagSertxdHexByte
    next
    sertxd(13,10);
    return

#rem ; EXAMPLE: RFM22 register dump (omitting $7f, the RX FIFO).
gosub DiagHexDumpHeaderWithZeros
for tempB3 = 0 to $7e
    ; Insert dump line headers as necessary
    B0 = tempB3 & 15
    if B0 = 0 then
        if tempB3 != 0 then : sertxd(13,10) : endif
        B0 = tempB3 / 16
        gosub DiagSertxdHexByte
        sertxd(" :")
    endif
    SPI_DATAB = tempB3
    gosub RFM22ReadReg8Bit
    ;sertxd("Reg ",#tempB3," = ",#SPI_DATAB,13,10)
    sertxd(" ")
    B0 = SPI_DATAB
    gosub DiagSertxdHexByte
next
sertxd(13,10)
#endrem


#endif
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
; Author(s) / Copyright (c): Damon Hart-Davis 2013

; ****** empty.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; Does nothing, takes no space, has no dependencies.

#ifdef USE_MODULE_EMPTY ; Only use content if explicitly requested.
#undefine USE_MODULE_EMPTY ; Prevent duplicate use...
    ; Nothing to see here, move along please...
#endif
