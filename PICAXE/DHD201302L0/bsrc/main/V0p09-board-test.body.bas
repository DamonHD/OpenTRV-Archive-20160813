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

; Exercises tests of the board and its components for use during and after build.
; For boards built incrementally allows tests in order hardware is usually added.

; I/O setup/initialisation prologue should leave board safe before this code starts.

#rem
Output seen on the AXEPad terminal at 4800 baud should look something like below,
cycling indefinitely unless an error is encountered:


Tests starting shortly... 3
Tests starting shortly... 2
Tests starting shortly... 1
LED_HEATCALL...
OUT_HEATCALL...
RTC... seconds=41
RFM22B...
  About to TX...
DS18B20... temp=18C
LDR... @253
BUTTON_MODE... @0
All tests completed OK!


Tests starting shortly... 3
Tests starting shortly... 2
#endrem


#define USE_MODULE_DIAGTOOLS ; Use diagnostic tools.
#define USE_MODULE_FHT8VSIMPLE_TX ; Use FHT8V TX support.

;-----------------------------------------
; SUBSET OF GLOBAL VARIABLES

; B0, B1, B2 (aka W0 and bit0 to bit23) reserved as working registers for bit manipulation.

; B3 as persistent global booleans
symbol globalFlags = B3 ; Global flag/boolean variables.
; Boolean flag 1/true if slow operation has been performed in main loop and no slow op should follow it.
symbol slowOpDone = bit24
; Boolean flag 1/true if in 'warm' mode (0 => 'frost' mode).
symbol isWarmMode = bit25
isWarmMode = 0 ; Start up not calling for heat.
; Boolean flag 1/true if room appears to be lit, or at least not in darkness.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
symbol isRoomLit = bit26
isRoomLit = 1 ; Start up assuming that the room is lit.
#else
symbol isRoomLit = 1 ; No LDR, so cannot tell when room is dark so assume always lit.
#endif
#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Boolean flag 1/true if synced with FHT8V, initially false.
symbol syncedWithFHT8V = bit27
; Boolean flag 1/true if target TRV should actually be open having received suitable command from this node (ie model of remote state).
symbol FHT8V_isValveOpen = bit28
#endif
; Boolean temporary.
symbol tempBit0 = bit31

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

#ifdef USE_MODULE_SPISIMPLE
; B16
; SPI routines usually read/write byte to/from here.
symbol SPI_DATAB = b16
#endif

; B18 & B19 (aka W9)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).
; W10 (aka B20 & B21)
; RESERVED FOR FHT8V_HC1 and FHT8V_HC2
symbol FHT8V_HC1 = 0
symbol FHT8V_HC2 = 0
#endif

; B24 & B25 (aka W12)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol syncStateFHT8V = B24 ; Sync status and down counter for FHT8V, initially zero; value not important once in sync.
; If syncedWithFHT8V = 0 then resyncing, AND
;     if syncStateFHT8V is zero then cycle is starting
;     if syncStateFHT8V in range [241,3] (inclusive) then sending sync command 12 messages.
symbol halfSecondsToNextFHT8VTX = B25 ; Nominal half seconds until next command TX.
#endif


symbol TEST_INDEX = B27 ; Current test index/number displayed in failure code.


#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Contiguous area used to store FHT8V TRV outgoing command for TX: must be at least 46 bytes long (50 if 4-byte RFM22 pre-preamble being used).
symbol FHT8VTXCommandArea = 0x50
#endif

; EEPROM data layout
symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8V: seq of (reg#,value) pairs term w/ $ff reg#.






; Run test suite indefinitely...
do
    ; Allow the terminal console to be brought up.
    for b0 = 3 to 1 step -1
        sertxd("Tests starting shortly... ",#b0,13,10)
        sleep 1
    next


    ; --------------------
    ; LED FLASH (0)
    ; --------------------
    TEST_INDEX = 0
    high LED_HEATCALL
    sertxd("LED_HEATCALL...",13,10)
    low LED_HEATCALL
    high OUT_HEATCALL
    sertxd("OUT_HEATCALL...",13,10)
    low OUT_HEATCALL


    ; --------------------
    ; RTC TEST (1)
    ; --------------------
    TEST_INDEX = 1
    gosub DS1306ReadBCDSecondsB0
    sertxd("RTC... seconds=")
    gosub DiagSertxdHexByte
    sertxd(13,10)
    ; Fail if RTC not connected (typically reads $ff) or not otherwise responding appropriately.
    if B0 > $59 then error


    ; --------------------
    ; RFM22B TEST (2)
    ; --------------------
    TEST_INDEX = 2
    sertxd("RFM22B...",13,10)
    ; Reset and go into low-power mode.
    gosub RFM22PowerOnInit
    ; Panic if not working as expected...
    gosub RFM22CheckConnected
    B0 = tempB0 ; Contains device type as read.
    if SPI_DATAB != 0 then error
    ; Send an aaaaaaaacccc sequence as if for the start of an FHT8V command.
    tempB0 = FHT8V_RFM22_Reg_Values
    gosub RFM22RegisterBlockSetup
    ; Standby mode.
    gosub RFM22ModeStandby
    sertxd("  About to TX...",13,10)
    ; Clear the TX FIFO.
    gosub RFM22ClearTXFIFO
    ; Load bit stream into RFM22 using burst-write mode...
    low RFM22_nSEL_O
    B0 = $ff ; TX FIFO (burst) write to register $7f.
    gosub SPI_shiftout_byte_MSB_preclB0
    ; Send out FHT8V encoded frame.
    B0 = $aa
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    B0 = $cc
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    high RFM22_nSEL_O
    gosub RFM22TXFIFO ; Send it!
    ; Should nominally pause about 8--9ms or similar before retransmission...
    nap 0
    gosub RFM22TXFIFO ; Re-send it!
    gosub RFM22ModeStandbyAndClearState


    ; --------------------
    ; DS18B20 TEMPERATURE SENSOR TEST (3)
    ; --------------------
    TEST_INDEX = 3
    readtemp TEMP_SENSOR, B0
    sertxd("DS18B20... temp=",#B0,"C",13,10)
    ; Reject insane temperatures (that may also indicate faulty connection).
    if B0 > 50 then error
    if B0 <= 0 then error


    ; --------------------
    ; LDR TEST (4)
    ; --------------------
    TEST_INDEX = 4
    readadc INPUT_LDR, B0
    sertxd("LDR... @",#B0,13,10)
    ; Reject values at either extreme that probably indicate a missing component or connection.
    if B0 = 255 then error
    if B0 = 0 then error


    ; --------------------
    ; SWITCH TEST (5)
    ; --------------------
    TEST_INDEX = 5
    sertxd("BUTTON_MODE... @",#BUTTON_MODE,13,10)
    ; No obvious actual test to perform here yet.












    ; Done: everything OK if this is reached.
    sertxd("All tests completed OK!",13,10,13,10,13,10)
loop
end

; Some routines may wish to abort with panic in case of serious trouble.
panic:
    do
        sertxd(13,10,"***PANIC***",13,10)
        sleep 4
    loop
    end

; Error exit from failed unit test number in TEST_INDEX, possible extra info in B0.
error:
    do
        sertxd(13,10,"***Test FAILED*** TEST_INDEX=",#TEST_INDEX,", B0=",#B0,13,10)
        sleep 4
    loop
    end









