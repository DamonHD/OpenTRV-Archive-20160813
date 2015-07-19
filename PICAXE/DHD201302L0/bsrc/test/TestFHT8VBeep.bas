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

; Test FHT8V radio access from 18M2+ by making the TRV go beep!

#picaxe 18M2

#define LOCAL_TRV ; Test TX code...




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
symbol RFM22_nIRL_I_PIN = input2
symbol RFM22_nIRL_I = C.2


; B18 & B19 (aka W9)
symbol FHT8V_HC1 = 48 ; 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 21 ; 73 ; House code 2, constant or (byte) register.
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).


; TX/RX scratchpad block...
symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area.
symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.

symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8: seq of (reg#,value) pairs term w/ $ff reg#.




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

#rem
; Register dump (omitting $7f, the RX FIFO)
for tempB3 = 0 to $7e
    SPI_DATAB = tempB3
    gosub RFM22ReadReg8Bit
    sertxd("Reg ",#tempB3," = ",#SPI_DATAB,13,10);
next
sleep 4
#endrem




; Create an FHT8V byte stream in ScratchMemBlock suitable to TX via RFM22, low byte first, msbit of each byte first.
FHT8V_CMD = $2e ; SBeep
FHT8V_EXT = 0
bptr = ScratchMemBlock
gosub FHT8VCreate200usBitStreamBptr


; Main loop; never exits.
do
    setfreq m32

    ; Queue the command.
    bptr = ScratchMemBlock
    gosub FHT8VQueueCmdViaRFM22Bptr

    setfreq m4

    ; Send it!
    high LED_HEATCALL
    gosub RFM22TXFIFO
    low LED_HEATCALL

    gosub RFM22ModeStandbyAndClearState ; Back to low-power standby mode.

    nap 5 ; << 1s

    #rem
    ; Register dump (omitting $7f, the RX FIFO)
    for tempB3 = 0 to $7e
        SPI_DATAB = tempB3
        gosub RFM22ReadReg8Bit
        sertxd("Reg ",#tempB3," = ",#SPI_DATAB,13,10);
    next
    sleep 4
    #endrem

loop ; end of main loop



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


