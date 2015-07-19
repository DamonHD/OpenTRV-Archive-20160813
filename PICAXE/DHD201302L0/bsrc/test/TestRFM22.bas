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

; Test low-level RFM22 radio access from 18M2+.

#picaxe 18M2

#define USE_MODULE_SPISIMPLE ; Use/test low-level SPI support.
#define USE_MODULE_RFM22RADIOSIMPLE ; Use RFM22 support.
#define USE_MODULE_FHT8VSIMPLE_TX ; Use simple FHT8V TX code.



; B.1: Red 'calling for heat' LED and other UI.
symbol LED_HEATCALL = B.7
low LED_HEATCALL ; send low ASAP


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
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.
symbol FHT8V_ADR = 0 ; Sub-address, constant or (byte) register.  0 for broadcast and fixed as a constant here.
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).
#endif

; TX/RX scratchpad block...
symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area.
symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.

symbol FHT8V_RFM22_Reg_Values = 8 ; Not necessarily at the start of the EEPROM...


#rem
; Setup data for the RFM22.
; Consists of a sequence of (reg#,value) pairs terminated with a $ff register number.  The reg#s are <128, ie top bit clear.
; Magic numbers c/o Mike S!
EEPROM RFM22_Reg_Values, ($8,0) ; RFM22REG_OP_CTRL2: ANTDIVxxx, RXMPK, AUTOTX, ENLDM
; Channel 0 frequency = 868 MHz, 10 kHz channel steps, high band.
EEPROM ($75,$73, $76,100, $77,0) ; BAND_SELECT,FB(hz), CARRIER_FREQ0&CARRIER_FREQ1,FC(hz) where hz=868MHz
EEPROM ($7a,1) ; One 10kHz channel step.
EEPROM ($79,35) ; 868.35 MHz - FHT
EEPROM ($73,0, $74,0) ; Frequency offset
EEPROM ($72,8) ; Deviation 5 kHz GFSK.
EEPROM ($71,$21) ; MOD CTRL 2: OOK modulation.
EEPROM ($6e,40, $6f,245); 5000bps, ie 200us/bit for FHT (6 for 1, 4 for 0).  10485 split across the registers, MSB first.
EEPROM ($70,$20) ; MOD CTRL 1: low bit rate (<30kbps), no Manchester encoding, no whitening.
;EEPROM ($6d,$f) ; RFM22REG_TX_POWER: Maximum TX power; not legal in UK with RFM22B on this band.
EEPROM ($6d,%00001101) ; RFM22REG_TX_POWER: Somewhat above minimum TX power.
;EEPROM ($6d,8) ; RFM22REG_TX_POWER: Minimum TX power (-1dBm).
; Probably only the first of these is vital.
; 0x30 = 0x00 - turn off packet handling
; 0x32 = 0x00 - turn off address checking (rx)
; 0x33 = 0x0a - turn off header, set fixed packet length (both n/a with packet handling off), set 2 byte sync
; 0x35 = 0x20 - set preamble threshold (rx)
; 0x36-0x39 = 0x2dd4 - set sync word (this is the default anyway)
EEPROM ($30,0, $32,0, $33,$a, $36,$2d, $37,$d4, $38,0, $39,0, $35,$20)
; For RFM22 with RXANT tied to GPIO0, and TXANT tied to GPIO1...
EEPROM ($b,$15, $c,$12) ; COMMENT OUT FOR RFM23
; Terminate the initialisation data.
EEPROM ($ff,$ff)
#endrem



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


; Create an FHT8V byte stream in ScratchMemBlock suitable to TX via RFM22, low byte first, msbit of each byte first.
FHT8V_CMD = $2e ; SBeep
FHT8V_EXT = 0
bptr = ScratchMemBlock
gosub FHT8VCreate200usBitStreamBptr



; Main loop; never exits.
do

    setfreq m32

    ; Fast burst write of precomputed bytes to RFM22...
    tempB0 = ScratchMemBlock
    low RFM22_nSEL_O
    B0 = $ff ; TX FIFO (burst) write.
    gosub SPI_shiftout_byte_MSB_preclB0
    do
        peek tempB0, B0
        if B0 = $ff then exit
        gosub SPI_shiftout_byte_MSB_preclB0
        inc tempB0
    loop
    high RFM22_nSEL_O

    ;setfreq m4

    ; Transmit FIFO content and then go back to low-power standby...
    high LED_HEATCALL
    gosub RFM22TXFIFO
    low LED_HEATCALL
    setfreq m4
debug

    gosub RFM22ModeStandbyAndClearState ; Back to low-power standby mode.


    nap 2

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


