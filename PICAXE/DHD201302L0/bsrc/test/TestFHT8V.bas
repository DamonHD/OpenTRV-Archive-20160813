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

; Test FHT8V radio access from 18M2+.

#picaxe 18M2

#define USE_MODULE_DIAGTOOLS ; Get diagnostic tools.


#define BOILER_HUB ; Test RX code...




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
symbol SPI_DATAB = b8            ; SPI write byte from here and read byte to here
symbol tempB0 = b14              ; temp working variable
symbol tempB1 = b15              ; temp working variable
symbol tempB2 = b16              ; temp working variable
symbol tempB3 = b17              ; temp working variable

symbol RFM22_nSEL_O = B.5; 18M2 p11


; B18 & B19 (aka W9)
symbol FHT8V_HC1 = 99; 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 99; 73 ; House code 2, constant or (byte) register.
;symbol FHT8V_ADR = 0 ; Sub-address, constant or (byte) register.  0 for broadcast and fixed as a constant here.
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).

symbol RSSI = b22


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
main:
    gosub RFM22ModeStandbyAndClearState ; Known state, FIFOs cleared, standby mode.

    ;gosub RFM22ModeTune ; Warm up the PLL for quick transition to RX below.

    ; Set FIFO RX almost-full threshold.
    SPI_DATAB = $7e ; RFM22REG_RX_FIFO_CTRL
    tempB2 = 34
    gosub RFM22WriteReg8Bit

    ; Turn off all other interrupts...
    SPI_DATAB = 5 ; RFM22REG_INT_ENABLE_1
    gosub RFM22WriteReg8Bit0
    ; Enable sync-detect interrupt.
    SPI_DATAB = 6 ; RFM22REG_INT_ENABLE_2
    tempB2 = $80
    gosub RFM22WriteReg8Bit

    gosub RFM22ClearInterrupts ; Clear any current status.
    gosub RFM22ModeRX ; Start listening...

    ; Try a few times (>1s) to see if a sync happens...
    for tempB1 = 0 to 150
        gosub RFM22ReadStatusBoth
        if SPI_DATAB >= $80 then ; Got sync!
            ;sertxd("*",#SPI_DATAB,13,10) ; generally expect 146 | $92

            high LED_HEATCALL
            nap 0
            low LED_HEATCALL

#rem
            ; Get RSSI
            SPI_DATAB = $26
            gosub RFM22ReadReg8Bit
            RSSI = SPI_DATAB
            ;sertxd("RSSI: ",#RSSI,13,10)
#endrem

#rem
            ; Turn off all other interrupts...
            SPI_DATAB = 5 ; RFM22REG_INT_ENABLE_1
            tempB2 = $10
            gosub RFM22WriteReg8Bit
            ; Enable RX-FIFO-full interrupt.
            SPI_DATAB = 6 ; RFM22REG_INT_ENABLE_2
            gosub RFM22WriteReg8Bit0
#endrem

            ; Poll for bytes to arrive...
            for tempB3 = 0 to 75 ; No more than 74ms to get all bytes...
                pause 1 ; 1.6ms between bytes @5kbps

#rem ; Poll for FIFO bytes : RX FIFO almost-full interrupt must be disabled.
                SPI_DATAB = 2 ; Device status
                gosub RFM22ReadReg8Bit
                B0 = tempB2
                if bit5 = 0 then ; At least one FIFO byte present...
                    SPI_DATAB = $7f
                    gosub RFM22ReadReg8Bit
                    sertxd(#SPI_DATAB,",")
                    if SPI_DATAB = $ff then exit ; End of frame...
                else if bit0 = 0 then ; No longer in RX mode
                else if tempB2 != $20 then ; Unexpected status...
                    sertxd("(",#tempB2,")");
                    tempB0 = tempB2 & $d8
                    if tempB0 != 0 then exit ; Non-recoverable errors.
                endif
#endrem

;#rem ; Wait for RX FIFO almost-full interrupt.
                gosub RFM22ReadStatusBoth
                if tempB0 >= $80 then ; FIFO overflow/underflow
                    sertxd("O",13,10)
                    exit
                endif
                tempB0 = tempB2 & $10
                if tempB0 != 0 then ; At least one FIFO byte should be present...
                    gosub getFrame
                    gosub dumpFrame
                    ;sertxd("D")
                    ;SPI_DATAB = $7f
                    ;gosub RFM22ReadReg8Bit
                    ;sertxd(#SPI_DATAB,",")
                    ;if SPI_DATAB = 0 OR SPI_DATAB = $ff then exit
                    exit
                else
                    sertxd("(",#tempB2,",",#SPI_DATAB,")");
                endif
;#endrem

            next tempB3

#rem
            high LED_HEATCALL
            nap 0
            low LED_HEATCALL
#endrem

            sertxd(13,10)

            exit ; Start main loop again...
        else if tempB2 >= $80 then ; RX FIFO overflow/underflow: give up

#rem
            SPI_DATAB = $7f
            gosub RFM22ReadReg8Bit
            if SPI_DATAB != 0 then
                sertxd("PFE: ",#SPI_DATAB,13,10)
                gosub getFrame
                gosub dumpFrame
            endif
#endrem

            high OUT_HEATCALL
            nap 1
            low OUT_HEATCALL
            exit
        else
            sertxd("?",#SPI_DATAB,13,10)
        endif

        ;nap 0
        pause 10
    next
goto main ; end of main loop


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
