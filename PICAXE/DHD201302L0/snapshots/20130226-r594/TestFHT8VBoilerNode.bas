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