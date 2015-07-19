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

; Test sync with FHT8V TRV (and beeping once synced) using once-per-second control loop.

#picaxe 18M2


#define LOCAL_TRV ; Test TX code...

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

; B.6: DS1306 RTC active high Chip Enable for SPI
symbol DS1306_CE_O = B.6
low DS1306_CE_O ; make inactive ASAP


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

; B3 as persistent global booleans
symbol globalFlags = B3 ; Global flag/boolean variables.
; Boolean flag 1/true if slow operation has been performed in main loop and no slow op should follow it.
symbol slowOpDone = bit24
; ...
#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Boolean flag 1/true if synced with FHT8V, initially false.
symbol syncedWithFHT8V = bit27
#endif


; B4 (aka part of W2)
; Current TRV value percent open (0--100 inclusive) and boiler heat-demand level.
; Anything other than zero may be treated as 100 by boiler or TRV.
symbol TRVPercentOpen = b4 ; Should start off at zero, ie rad closed, boiler off.


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
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.
;symbol FHT8V_ADR = 0 ; Sub-address, constant or (byte) register.  0 for broadcast and fixed as a constant here.
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).

; B24 & B25 (aka W12)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol syncStateFHT8V = B24 ; Sync status and down counter for FHT8V, initially zero; value not important once in sync.
; If syncedWithFHT8V = 0 then resyncing, AND
;     if syncStateFHT8V is zero then cycle is starting
;     if syncStateFHT8V in range [241,3] (inclusive) then sending sync command 12 messages.
symbol halfSecondsToNextFHT8VTX = B25 ; Nominal half seconds until next command TX.
#endif

; B26
; Count of missed ticks (and sync restarts).
symbol missedTickCount = B26



#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Contiguous area used to store FHT8V TRV outgoing command for TX: must be at least 46 bytes long.
symbol FHT8VTXCommandArea = 0x50
#endif

symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8: seq of (reg#,value) pairs term w/ $ff reg#.



high LED_HEATCALL

; Power-on minimal init.
gosub RFM22PowerOnInit

; Check that a RFM22 seems to be correctly connected.
gosub RFM22CheckConnected
if SPI_DATAB != 0 then panic

; Check that a RFM22 still seems to be correctly connected even when using a faster clock.
gosub setHighClockSpeed
gosub RFM22CheckConnected
if SPI_DATAB != 0 then panic
gosub setNormalClockSpeed


; Standby mode.
gosub RFM22ModeStandby

; Test block setup of registers.
tempB0 = FHT8V_RFM22_Reg_Values
gosub RFM22RegisterBlockSetup

low LED_HEATCALL




; Main loop; never exits.
; Rough emulation of main loop from TRVControl.bas.
do
    slowOpDone = 0

    if halfSecondsToNextFHT8VTX < 6 then : high LED_HEATCALL : endif

    gosub setHighClockSpeed ; Turn on turbo mode.
    gosub FHT8VPollSyncAndTX ; Manage comms with TRV
    bptr = FHT8VTXCommandArea
    if @bptr = $ff AND slowOpDone = 0 then ; Sync complete: needs real command in buffer ASAP when not running too late.
        gosub setUpBeep
        slowOpDone = 1
    endif
    gosub setNormalClockSpeed ; Turn off turbo mode.

    low LED_HEATCALL





    ; DO NORMAL STUFF IN MAIN BODY OF LOOP





schedule: ; Do general job scheduling (quickly) for next interaction just before the end of this loop.




    ; Wait for elapsed time to roll...

    debug ; Can be a handy spot to inspect memory...


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
            ; TODO check for and act on missed ticks eg maybe force resync.
            tempB1 = TIME_LSD + 1 ; Expected new value for TIME_LSD given previous.
            if tempB1 != tempB0 then
#ifndef TIME_LSD_IS_BINARY ; Extra corrections for BCD increment and minute roll...
                tempB2 = tempB1 & $f
                if tempB2 = $a then : tempB1 = tempB1 + 6 : endif
                if tempB1 = $60 then : tempB1 = 0 : endif
                if tempB1 != tempB0 then
#endif
                    inc missedTickCount

#ifdef USE_MODULE_FHT8VSIMPLE_TX
                    ; Set back to initial unsynchronised state and force resync with TRV.
                    gosub FHT8VSyncAndTXReset
#endif

                    debug ; MISSED AT LEAST ONE TICK

#ifndef TIME_LSD_IS_BINARY
                endif
#endif
            endif

            ; TODO if (masked) time rolls to a smaller number then trigger the minute counter; robust even if individual seconds get missed.
            TIME_LSD = tempB0
            exit
        endif



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

loop ; end of main loop

end


; PANIC
; In case of hardware not working correctly stop doing anything difficult/dangerous
; while indicating distress to users and conserving power if possible.
panic:
    debug
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


; Create an FHT8V byte stream in FHT8VTXCommandArea suitable to TX via RFM22, low byte first, msbit of each byte first.
setUpBeep:
    FHT8V_CMD = $2e ; Beep
    FHT8V_EXT = 0
    bptr = FHT8VTXCommandArea
    gosub FHT8VCreate200usBitStreamBptr
    return