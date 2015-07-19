
; GENERATED/OUTPUT FILE: DO NOT EDIT!
; Built 2014/19/08 17:19.
; ZERO-HARDWARE TEST STUB.
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

; Board hardware and I/O config for V0.09 board as of 20130313 for test and production code.
; Should be included and executed early to set pins to safe I/O state, ie input, or output and level.





#ifdef 18M2 ; valid for 18M2+ in V0.09 board, only.

;-----------------------------------------
; Force definitions for peripherals that should be present on every V0.09 board
; (though may be ignored or not added to the board)
; to enable safe I/O setup and (eg) avoid bus conflicts.
#define USE_MODULE_RFM22RADIOSIMPLE ; Always fitted on V0.09 board.
#define USE_MODULE_SPISIMPLE ; Required dependency.

#define USE_MODULE_DS1306RTCSPISIMPLE ; Could in principle be omitted in some cases to use PICAXE elapsed time instead.
#define USE_MODULE_SPISIMPLE ; Required dependency.

#define USE_MODULE_LDROCCUPANCYDETECTION ; Can be omitted where occupancy sensing with LDR not useful, eg for DHW.


;-----------------------------------------
; INPUTS / SENSORS (primarily)
; ---- C PINS ----  (can include some outputs and bidirectional)
dirsC = %00000000 ; All inputs basically.

;#ifdef USE_MODULE_LDROCCUPANCYDETECTION
; C.0: LDR light sensor (ADC input); higher voltage indicates more ambient light.
; Should be pulled low externally whether LDR used or not, so can be left as input or set to low output.
symbol INPUT_LDR = C.0
;#endif

; C.1: Momentary button active high to toggle between off and warm modes (logic-level input).
; Should be pulled low externally, so can be left as input or set to low output.
symbol BUTTON_MODE = input1 ; C.1

; C.2: UNALLOCATED
; Should be pulled high externally, so can be left as input or set to high output.
; (May become CE (output) for MAX31723 temperature sensor: 1.7V to 3.7V, +/-0.5C accuracy, SPI bus.)
; (May become low-duty-cycle sensor supply +V output to reduce consumption, eg of LDR circuit.)
; (May become analogue thermistor potential divider input.)

; C.3/C.4: RESERVED: (C.4 serial in, C.3 serial out)

; C.5 UNALLOCATED (logic input only)
; (May be used experimentally as 1Hz input from RTC for better low-power sleep.)
; (May be used experimentally as monetary pull-down input from 'learn' button.)
; C.5 is reset on 18X parts, but not on 18M2.
; Should be pulled high externally, so can be left as input.

;#ifdef USE_MODULE_SPISIMPLE
; C.6: SPI serial protocol data input
symbol SPI_SDI = C.6
symbol SPI_SDI_PIN = input6 ; C.6
;input C.6
;#endif

; C.7: DQ connection of DS18B20 1-Wire temperature sensor.
; Should be pulled high externally, bidirectional in use.
; (May become low-duty-cycle sensor supply +V output to reduce consumption, eg of LDR circuit.)
symbol TEMP_SENSOR = C.7


;-----------------------------------------
; OUTPUTS (primarily)
; ---- B PINS ---- (can include some inputs)
dirsB = %11101101 ; Set outputs where there is no conflict.  Stops pins floating and wasting power.
;pullup %00010010 ; Weak pull-ups for i2c lines (B.4 & B.1) in case external pull-ups not fitted to avoid floating.

; B.0: Direct DC active high output to call for heat, eg via SSR.
symbol OUT_HEATCALL = B.0
low OUT_HEATCALL ; Send low ASAPn to avoid firing up an attached boiler spuriously.

; B.1 i2c SDA on 18M2: RESERVED.
; Should be pulled up externally so can be input or high output (to avoid floating).

;#ifdef USE_MODULE_SPISIMPLE
; B.2: SPI clock (output).
symbol SPI_SCLK_O = B.2
;output B.2
; B.3: SPI data (output).
symbol SPI_SDO = B.3
symbol SPI_SDO_PIN = outpinB.3 ; SPI data (output) in pinX.Y format.
;output B.3
;#endif

; B.4: i2c SCL on 18M2: RESERVED.
; Should be pulled up externally so can be input or high output (to avoid floating).

;#ifdef USE_MODULE_RFM22RADIOSIMPLE
; B.5: RFM22 radio active low negative select.
symbol RFM22_nSEL_O = B.5
high RFM22_nSEL_O ; Make inactive ASAP unconditionally to avoid possible damage.
;#endif

;#ifdef USE_MODULE_DS1306RTCSPISIMPLE
; B.6: DS1306 RTC active high Chip Enable for SPI
; (May become low-duty-cycle sensor supply +V output to reduce consumption, eg of LDR circuit.)
symbol DS1306_CE_O = B.6
low DS1306_CE_O ; Make inactive ASAP unconditionally to avoid possible damage.
;#endif

; B.7: Red active high 'calling for heat' LED and other UI.
symbol LED_HEATCALL = B.7
high LED_HEATCALL ; Send high (on) ASAP during initialisation to show that something is happening...




#else
#error ONLY 18M2+ SUPPORTED
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

; Generic Computational Unit Tests.
; These tests do not require any peripherals and are intended only to test computations,
; so enable only the pure-computation features of any library modules linked.
; There is an initial pause to allow the terminal console to be brought up.
; These tests will stop upon the first failure with a failure message on the console,
; repeated periodically.
; Additionally some error information should have been written with sertxd().
; Other (low-volume) progress information may be written with sertxd() also.
; On success of all tests a success message is written to the console,
; repeated periodically,
; and the tests will be re-run (ie indefinitely until an error is encountered).

#picaxe 18M2

#define DEBUG ; enable extra internal checking

; Flag to try defined and not, to check that performance/size tradeoffs don't break anything.
#define REDUCE_CODE_SPACE



; Common setup.
symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area.
symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.

; EEPROM allocation: some allocated spaces may not be used.
symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8: seq of (reg#,value) pairs term w/ $ff reg#.

;-----------------------------------------
; GLOBAL VARIABLES
; B0, B1, B2 (aka W0 and bit0 to bit23) reserved as working registers and for bit manipulation.

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
;
; Boolean temporary.
symbol tempBit0 = bit31

; B10 & B11 (aka W5)
; Temp/scratch bytes 0 & 1 and OVERLAID temp word 0.  Not expected to survive subroutine calls, etc.
symbol tempB0 = b10
symbol tempB1 = b11
symbol tempW0 = w5
; B10 & B11 (aka W5)
; Temp/scratch bytes 2 & 3 and OVERLAID temp word 1.  Not expected to survive subroutine calls, etc.
symbol tempB2 = b12
symbol tempB3 = b13
symbol tempW1 = w6

#ifdef USE_MODULE_SPISIMPLE
; B16
; SPI routines usually read/write byte to/from here.
symbol SPI_DATAB = b16
#endif


; Run test suite indefinitely...
do
    ; Allow the terminal console to be brought up.
    for b0 = 3 to 1 step -1
        sertxd("Tests starting shortly... ",#b0,13,10)
        sleep 1
    next


    ; FHT8V off-line tests
    ; --------------------
    #define USE_MODULE_FHT8VSIMPLE_TX ; Enable testable module elements...
    symbol FHT8V_HC1 = b20 ; House code 1, constant or (byte) register.
    symbol FHT8V_HC2 = b21 ; House code 2, constant or (byte) register.
    symbol FHT8V_ADR = b22 ; Sub-address, constant or (byte) register.  Usually 0.
    symbol FHT8V_CMD = b23 ; Command byte register (set valve to given open fraction).
    symbol FHT8V_EXT = b24 ; Command extension byte register (valve shut).
    FHT8V_HC1 = 13
    FHT8V_HC2 = 73
    #define FHT8V_ADR_USED
    FHT8V_ADR = 0
    FHT8V_CMD = $26
    FHT8V_EXT = 0
    sertxd("FHT8V...",13,10)
    ;
    ; Create an FHT byte stream suitable to TX via RFM22, low byte first, msbit of each byte first.
    ; EXPECTED RESULT: close valve, on the wire variable bit width encoding: length 38   , 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xe3, 0x33, 0x33, 0x8e, 0x33, 0x8e, 0x33, 0x8c, 0xce, 0x33, 0x38, 0xe3, 0x33, 0x33, 0x33, 0x33, 0x33, 0x38, 0xcc, 0xe3, 0x8c, 0xe3, 0x33, 0x33, 0x33, 0x33, 0x38, 0xcc, 0xce, 0x33, 0x33, 0x30
    bptr = ScratchMemBlock
    gosub FHT8VCreate200usBitStreamBptr
    ; Check that the stream is terminated correctly within the allowed space.
    for tempB0 = ScratchMemBlock to ScratchMemBlockEnd
        peek tempB0, tempB1
;sertxd(#tempB1,", ") ; Dump generated bytes!
        if tempB1 = $ff then FHT8VFoundTermination
    next
    sertxd(" TX terminator not found",13,10)
    goto error
    FHT8VFoundTermination: ; Found terminator OK.
;sertxd(13,10)
    ; Check that byte stream has expected length.
    tempB0 = tempB0 - ScratchMemBlock
    if tempB0 != 38 then
        sertxd(" TX msg wrong length: ",#tempB0,13,10)
        goto error
    endif
    sertxd(" term OK",13,10) ; Short status/progress message to save space...
    ; Sample preamble and some other key bytes.
    peek ScratchMemBlock, tempB0 ; First byte of preamble.
    if tempB0 != $cc then
        sertxd(" bad preamble @0",13,10);
        goto error
    end if
    tempB0 = ScratchMemBlock + 6
    peek tempB0, tempB0 ; End of preamble.
        if tempB0 != $e3 then
        sertxd(" bad preamble @6 ",#tempB0,13,10);
        goto error
    end if
    tempB0 = ScratchMemBlock + 34
    peek tempB0, tempB0 ; Part of checksum.
        if tempB0 != $ce then
        sertxd(" bad checksum @34 ",#tempB0,13,10);
        goto error
    end if
    sertxd(" byte stream OK",13,10) ; Short status/progress message to save space...

    ; Set up and encode the shortest possible message (all zero bits).
    FHT8V_HC1 = 0
    FHT8V_HC2 = 0
    FHT8V_ADR = 0
    FHT8V_CMD = 0
    FHT8V_EXT = 0
    bptr = ScratchMemBlock
    gosub FHT8VCreate200usBitStreamBptr
    ; Check that the stream is terminated correctly within the allowed space.
    for tempB0 = ScratchMemBlock to ScratchMemBlockEnd
        peek tempB0, tempB1
;sertxd(#tempB1,", ") ; Dump generated bytes!
        if tempB1 = $ff then FHT8VFoundTermination2
    next
    sertxd(" short TX terminator not found",13,10)
    goto error
    FHT8VFoundTermination2: ; Found terminator OK.
;sertxd(13,10)
    ; Check that byte stream has expected length.
    tempB0 = tempB0 - ScratchMemBlock
    if tempB0 != 35 then
        sertxd(" short TX msg wrong length: ",#tempB0,13,10)
        goto error
    endif

    ; Set up and encode the longest possible message (all one bits other than parity).
    FHT8V_HC1 = $ff
    FHT8V_HC2 = $ff
    FHT8V_ADR = $ff
    FHT8V_CMD = $ff
    FHT8V_EXT = $ff
    bptr = ScratchMemBlock
    gosub FHT8VCreate200usBitStreamBptr
    ; Check that the stream is terminated correctly within the allowed space.
    for tempB0 = ScratchMemBlock to ScratchMemBlockEnd
        peek tempB0, tempB1
;sertxd(#tempB1,", ") ; Dump generated bytes!
        if tempB1 = $ff then FHT8VFoundTermination3
    next
    sertxd(" long TX terminator not found",13,10)
    goto error
    FHT8VFoundTermination3: ; Found terminator OK.
;sertxd(13,10)
    ; Check that byte stream has expected length.
    tempB0 = tempB0 - ScratchMemBlock
    if tempB0 != 45 then
        sertxd(" long TX msg wrong length: ",#tempB0,13,10)
        goto error
    endif










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

; Error exit from failed unit test.
error:
    do
        sertxd(13,10,"***Test FAILED.***",13,10)
        sleep 4
    loop
    end
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

; ****** BCDtools.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; BCD arithmetic tools.

#ifdef USE_MODULE_BCDTOOLS ; Only use content if explicitly requested.

; Convert the BCD value in B0 to binary in B1.
; B0 is not altered.
BCDtoBinary:
    B1 = B0 & $f
    B1 = B0 / 16 * 10 + B1
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

; ****** DS1306-RTC-SPI-simple.inc.bas ****** in module library
; Basic support for DS1306 2V--5V RTC in SPI mode.
; Appendable PICAXE basic fragment.



; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol DS1306_CE_O ; output bit


; NOTE: 1Hz output signal appears to be high for the 1st half of each second (DHD20130318) and enabled by default (bit 2 in reg $f).


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

#rem
; Reads the seconds register (in BCD, from 0--$59) into SPI_DATAB.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSeconds:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclock
    low DS1306_CE_O
    return
#endrem

; Reads the seconds register (in BCD, from 0--$59) into B0.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSecondsB0:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclB0
    low DS1306_CE_O
    return

; Reads the hours and minutes registers (in BCD, 0--$23 and 0--$59) into B0 and SPI_DATAB respectively.
DS1306ReadBCDHoursMinutes:
    high DS1306_CE_O
    B0 = 1
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftin_byte_MSB_postclB0
    SPI_DATAB = B0
    gosub SPI_shiftin_byte_MSB_postclB0
    low DS1306_CE_O
    return

; Set hours and minutes registers (in BCD, 0--$23 and 0--$59) from B1 and SPI_DATAB respectively.
DS1306SetBCDHoursMinutes:
    high DS1306_CE_O
    B0 = 1
    gosub SPI_shiftout_byte_1MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclock ; Write SPI_DATAB.
    B0 = B1
    gosub SPI_shiftout_byte_MSB_preclB0 ; Write B1.
    low DS1306_CE_O
    return

#ifdef DS1306RTC_8K1D_TRICKLE_CHARGE // Trickle-charge supercap attached to Vcc2.
DS1306Set8K1DTickleCharge:
    high DS1306_CE_O
    B0 = 0x11
    gosub SPI_shiftout_byte_1MSB_preclB0
    B0 = 0xA7 ; // 8k resistor, 1 diode.
    gosub SPI_shiftout_byte_MSB_preclB0
    low DS1306_CE_O
    return
#endif

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
;
; For details of sync between this and FHT8V see https://sourceforge.net/p/opentrv/wiki/FHT%20Protocol/

; RECENT CHANGES
; DHD20130324: No longer try to send actual TRVPercentOpen on final sync (cmd 0) in FHT8VPollSyncAndTX: anything other than zero seems to lock up FHT8V-3 units.
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
; symbol FHT8V_RFM22_Reg_Values ; start address in EEPROM for register setup values.
; #define DEBUG (optional) ; enables extra checking, eg during unit tests.
; #define RFM22_IS_ACTUALLY_RFM23 (optional) ; indicates that RFM23B module is being used in place of RFM22B.
; #define USE_MODULE_RFM22RADIOSIMPLE (optional) ; to include some specific RFM22 support.
; symbol syncedWithFHT8V (bit, true once synced)
; symbol FHT8V_isValveOpen (bit, true if node has sent command to open TRV)
; symbol syncStateFHT8V (byte, internal)
; symbol halfSecondsToNextFHT8VTX (byte)
; symbol TRVPercentOpen (byte, in range 0 to 100) ; valve open percentage to convey to FHT8V
; symbol slowOpDone (bit) ; set to 1 if a routine takes significant time
; symbol FHT8VTXCommandArea (byte block) ; for FHT8V outgoing commands
; panic: ; Label for any routine to jump to to abort system operation as safely as possible.





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

; From AN440: The output power is configurable from +13 dBm to ?8 dBm (Si4430/31), and from +20 dBM to ?1 dBM (Si4432) in ~3 dB steps. txpow[2:0]=000 corresponds to min output power, while txpow[2:0]=111 corresponds to max output power.
; The maximum legal ERP (not TX output power) on 868.35 MHz is 25 mW with a 1% duty cycle (see IR2030/1/16).
;EEPROM ($6d,%00001111) ; RFM22REG_TX_POWER: Maximum TX power: 100mW for RFM22; not legal in UK/EU on RFM22 for this band.
;EEPROM ($6d,%00001000) ; RFM22REG_TX_POWER: Minimum TX power (-1dBm).
#ifndef RFM22_IS_ACTUALLY_RFM23
    #ifndef RFM22_GOOD_RF_ENV
    EEPROM ($6d,%00001101) ; RFM22REG_TX_POWER: RFM22 +14dBm ~25mW ERP with 1/4-wave antenna.
    #else ; Tone down for good RF backplane, etc.
    EEPROM ($6d,%00001001)
    #endif
#else
    #ifndef RFM22_GOOD_RF_ENV
    EEPROM ($6d,%00001111) ; RFM22REG_TX_POWER: RFM23 max power (+13dBm) for ERP ~25mW with 1/4-wave antenna.
    #else ; Tone down for good RF backplane, etc.
    EEPROM ($6d,%00001011)
    #endif
#endif

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
EEPROM ($ff)

#rem ; DHD20130226 dump
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 AA CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0B 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37
#endrem
#endif



#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use TX support content if explicitly requested.

#ifdef USE_MODULE_RFM22RADIOSIMPLE ; RFM22 module must be loaded to use this.

; Call once per second to manage initial sync and subsequent comms with FHT8V valve.
; Requires globals defined that this maintains:
;     syncedWithFHT8V (bit, true once synced)
;     syncStateFHT8V (byte, internal)
;     halfSecondsToNextFHT8VTX (byte)
; Use globals maintained/set elsewhere / shared:
;     TRVPercentOpen (byte, in range 0 to 100) valve open percentage to convey to FHT8V
;     slowOpDone (bit) set to 1 if this routine takes significant time
;     FHT8VTXCommandArea (byte block) for FHT8V outgoing commands
; Can be VERY CPU AND I/O INTENSIVE so running at high clock speed may be necessary.
; If on exit the first byte of the command buffer has been set to 0xff
; then the command buffer should immediately (or within a few seconds)
; have a valid outgoing command put in it for the next scheduled transmission to the TRV.
; The command buffer can then be updated whenever required for subsequent async transmissions.
;
; See https://sourceforge.net/p/opentrv/wiki/FHT%20Protocol/
FHT8VPollSyncAndTX:
    if syncedWithFHT8V = 0 then
        ; Give priority to getting in sync over all other tasks, though pass control to them afterwards...
        ; NOTE: startup state, or state to force resync is: syncedWithFHT8V = 0 AND syncStateFHT8V = 0
        if syncStateFHT8V = 0 then
            ; Starting sync process.
            syncStateFHT8V = 241
        endif

        if syncStateFHT8V >= 3 then
            ; Generate and send sync (command 12) message immediately.
            FHT8V_CMD = $2c ; Command 12, extension byte present.
            FHT8V_EXT = syncStateFHT8V
            syncStateFHT8V = syncStateFHT8V - 2
            bptr = FHT8VTXCommandArea
            gosub FHT8VCreate200usBitStreamBptr
            bptr = FHT8VTXCommandArea
            gosub FHT8VTXFHTQueueAndTwiceSendCmd ; SEND SYNC
            ; On final tick set up time to sending of final sync command.
            if syncStateFHT8V = 1 then
                ; Set up timer to sent sync final (0) command
                ; with formula: t = 0.5 * (HC2 & 7) + 4 seconds.
                halfSecondsToNextFHT8VTX = FHT8V_HC2 & 7 + 8 ; Note units of half-seconds for this counter.
            endif

            slowOpDone = 1 ; Will have eaten up lots of time...
        else ; < 3 so waiting to send sync final (0) command...

            if halfSecondsToNextFHT8VTX >= 2 then
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX - 2
            endif

            if halfSecondsToNextFHT8VTX < 2 then

                ; Set up correct delay to this TX and next TX dealing with half seconds if need be.
                gosub FHT8VTXGapHalfSeconds
                if halfSecondsToNextFHT8VTX = 1 then ; Need to pause an extra half-second.
                    pause 500
                endif
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX + tempB0

                ; Send sync final command.
                FHT8V_CMD = $20 ; Command 0, extension byte present.
                FHT8V_EXT = 0 ; DHD20130324: could set to TRVPercentOpen, but anything other than zero seems to lock up FHT8V-3 units.
                bptr = FHT8VTXCommandArea
                gosub FHT8VCreate200usBitStreamBptr
                bptr = FHT8VTXCommandArea
                gosub FHT8VTXFHTQueueAndTwiceSendCmd ; SEND SYNC FINAL

                ; Assume now in sync...
                syncedWithFHT8V = 1

                ; Mark buffer as empty to get it filled with the real TRV valve-setting command ASAP.
                poke FHT8VTXCommandArea, $ff

                slowOpDone = 1 ; Will have eaten up lots of time already...
            endif
        endif

    else ; In sync: count down and send command as required.
            if halfSecondsToNextFHT8VTX >= 2 then
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX - 2
            endif

            if halfSecondsToNextFHT8VTX < 2 then

                ; Set up correct delay to this TX and next TX dealing with half seconds if need be.
                gosub FHT8VTXGapHalfSeconds
                if halfSecondsToNextFHT8VTX = 1 then ; Need to pause an extra half-second.
                    pause 500
                endif
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX + tempB0

                ; Send already-computed command to TRV.
                ; Queue and send the command.
                bptr = FHT8VTXCommandArea
                gosub FHT8VTXFHTQueueAndTwiceSendCmd

                ; Assume that command just sent reflects the current TRV internal model state.
                ; If TRVPercentOpen is not zero assume that remote valve is now open(ing).
                if TRVPercentOpen = 0 then : FHT8V_isValveOpen = 0 : else : FHT8V_isValveOpen = 1 : endif

                slowOpDone = 1 ; Will have eaten up lots of time...
            endif
    endif
    return


; Call to reset comms with FHT8V valve and force resync.
; Resets values to power-on state so need not be called in program preamble if variables not tinkered with.
; Requires globals defined that this maintains:
;     syncedWithFHT8V (bit, true once synced)
;     FHT8V_isValveOpen (bit, true if this node has last sent command to open valve)
;     syncStateFHT8V (byte, internal)
;     halfSecondsToNextFHT8VTX (byte).
FHT8VSyncAndTXReset:
    syncedWithFHT8V = 0
    syncStateFHT8V = 0
    halfSecondsToNextFHT8VTX = 0
    FHT8V_isValveOpen = 0
    return

; Compute interval (in half seconds) between TXes for FHT8V given FHT8V_HC2.
; (In seconds, the formula is t = 115 + 0.5 * (HC2 & 7) seconds.)
; Result returned in tempB0.
FHT8VTXGapHalfSeconds:
    tempB0 = FHT8V_HC2 & 7 + 230 ; Calculation strictly left-to-right.
    return

; Create FHT8V TRV outgoing valve-setting command frame (terminated with $ff) at bptr.
; The TRVPercentOpen value is used to generate the frame.
; On entry FHT8V_HC1, FHT8V_HC2 (and FHT8V_ADR if used) must be set correctly.
; The generated command frame can be resent indefinitely.
; This is CPU intensive, so can be run at a high clock speed if required.
; Destroys: bptr, tempW0.
FHT8VCreateValveSetCmdFrame:
    FHT8V_CMD = $26 ; Set valve to specified open fraction [0,255] => [closed,open].
    tempW0 = TRVPercentOpen * 255
    FHT8V_EXT = tempW0 / 100 ; Set valve open to desired %age.
#ifdef RFM22_SYNC_ONLY_BCFH
    ; Huge cheat: only add RFM22-friendly pre-preamble if calling for heat from the boiler (TRV not closed).
    ; NOTE: this requires more buffer space and technically we are overflowing the original FHT8VTXCommandArea.
    if TRVPercentOpen != 0 then
        @bptrinc = $aa
        @bptrinc = $aa
        @bptrinc = $aa
        @bptrinc = $aa
    endif
#endif
    goto FHT8VCreate200usBitStreamBptr ; GOSUB CHAIN: gosub FHT8VCreate200usBitStreamBptr return ; For speed and to preserve gosub slots.

; Sends to FHT8V in FIFO mode command bitstream from buffer starting at bptr up until terminating 0xff, then reverts to low-power standby mode.
; The trailing 0xff is not sent.
; Returns immediately without transmitting if the command buffer starts with 0xff (ie is empty).
; (Sends the bitstream twice, nominally with a short (~8ms) pause between transmissions, to help ensure reliable delivery.)
FHT8VTXFHTQueueAndTwiceSendCmd:
    if @bptr = 0xff then : return : endif
    gosub FHT8VQueueCmdViaRFM22Bptr
    gosub RFM22TXFIFO ; Send it!
    ; Should nominally pause about 8--9ms or similar before retransmission...
    ; (Though overheads of getting in out of RFM22TXFIFO routine will likely swamp that anyway.)
#rem
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 8
#else
    nap 0
#endif
#endrem
    gosub RFM22TXFIFO ; Re-send it!
    goto RFM22ModeStandbyAndClearState ; GOSUB CHAIN: gosub RFM22ModeStandbyAndClearState return ; For speed and to preserve gosub slots.

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
; Byte stream is terminated by $ff byte which is not a possible valid encoded byte.
; On entry, FHT8V_HC1, FHT8V_HC2, FHT8V_ADR (0 if undefined), FHT8V_CMD and FHT8V_EXT are inputs (and not destroyed if registers).
; On exit, the memory block starting at ScratchMemBlock contains the low-byte, msbit-first bit, $ff-terminated TX sequence.
; The maximum and minimum possible encoded message sizes are 35 (all zero bytes) and 45 (all $ff bytes) bytes long.
; Note that a buffer space of at least 46 bytes is needed to accommodate the longest message and the terminator.
; B0, tempB1 are destroyed.
; bptr is pointing to the terminating $ff on exit.
FHT8VCreate200usBitStreamBptr:
    ; Generate FHT8V preamble.
    ; First 12 x 0 bits of preamble, pre-encoded as 6 x 0xcc bytes.
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
            case 3 ; Empty target byte (should be 0xff currently).
                @bptr = %11001101 ; Write back partial byte (msbits now 1100 and two bit pairs remain free).
            case 2 ; Top bit pair already filled.
                @bptr    = @bptr & %11000000 | %110000 ; Preserve existing ms bit-pair, set middle four bits 1100, one bit pair remains free.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1100 ; Preserve existing (2) ms bit-pairs, set bottom four bits 1100, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            else ; Top three bit pairs already filled.
                ;@bptrinc = @bptr & %11111100 |     %11 ; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptrinc = @bptr             |     %11 ; Preserve existing (3) ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
        endselect
    else ; Appending 111000
        select case tempB1
            case 3 ; Empty target byte (should be 0xff currently).
                @bptr = %11100000 ; Write back partial byte (msbits now 111000 and one bit pair remains free).
            case 2 ; Top bit pair already filled.
                @bptrinc = @bptr & %11000000 | %111000 ; Preserve existing ms bit-pair, set lsbits to 111000, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1110; Preserve existing (2) ms bit-pairs, set bottom four bits to 1110, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
            else ; Top three bit pairs already filled.
                ;@bptrinc = @bptr & %11111100 |     %11; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptrinc = @bptr             |     %11; Preserve existing (3) ms bit-pairs, OR in leading 11 bits, write back full byte.
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
#ifdef REDUCE_CODE_SPACE_FHT8V ; Reduce code space in return for slightly lower performance.
    gosub _FHT8VCreate200usABEPb ; Original bit 6.
    gosub _FHT8VCreate200usABEPb ; Original bit 5.
    gosub _FHT8VCreate200usABEPb ; Original bit 4.
    gosub _FHT8VCreate200usABEPb ; Original bit 3.
    gosub _FHT8VCreate200usABEPb ; Original bit 2.
    gosub _FHT8VCreate200usABEPb ; Original bit 1.
    gosub _FHT8VCreate200usABEPb ; Original bit 0.
#else
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
#endif
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    bit7 = bit0 ; Computed parity is in bit 0...
    goto _FHT8VCreate200usAppendEncBit ; GOSUB CHAIN: gosub _FHT8VCreate200usAppendEncBit return ; For speed and to preserve gosub slots.

#ifdef REDUCE_CODE_SPACE_FHT8V
; Shift up one bit while updating parity in bit0, and encode new MSbit.
; Avoids an extra level of stack recursion.
_FHT8VCreate200usABEPb:
    if bit7 = 0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    goto _FHT8VCreate200usAppendEncBit ; GOSUB CHAIN: gosub _FHT8VCreate200usAppendEncBit return ; For speed and to preserve gosub slots.
#endif


#endif USE_MODULE_FHT8VSIMPLE_TX




#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use RX support content if explicitly requested.
; TODO
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
; DHD20130301: Added optional LDR_EXTRA_SENSITIVE for LDR not exposed to direct light to boost sensitivity.
; DHD20130225: Changed global this sets to "isRoomLit" and also uses it to provide hysteresis.
; DHD20130221: Bumped threshold up a little to 33 (~13%) based on observations.


; Dependencies:
; INPUT_LDR ADC input pin symbol must be defined with LDR to +V and pull-down to 0V (so more light gives higher value).
; #ifdef LDR_EXTRA_SENSITIVE (optional) ; Define this if LDR not exposed to much light, eg behind a grille.
; isRoomLit bit symbol must be defined; will be set to 1 if room is light enough for occupancy/activity, 0 otherwise.
; tempB0 temporary byte symbol must be defined; will be used/overwritten.
; #ifdef OMIT_MODULE_LDROCCUPANCYDETECTION suppresses inclusion of module code.

; Using techsupplies.co.uk SEN002 (like GL5528 1M+ dark, ~10k @ 10 Lux) with fixed pull-down resistor.
; Works OK with 10k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (5V) at threshold of 25 (~10% max).
; Works OK with 100k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (3.3V) at threshold of 25 (~10% max).  ("Dark" at night ~5.)



#ifdef USE_MODULE_LDROCCUPANCYDETECTION ; Only use content if explicitly requested.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION

#ifdef LDR_EXTRA_SENSITIVE ; Define if LDR not exposed to much light.
symbol LDR_THR_LOW = 5
symbol LDR_THR_HIGH = 8
#else ; Normal settings.
symbol LDR_THR_LOW = 30
symbol LDR_THR_HIGH = 35
#endif


; Attempts to detect potential room use/occupancy from ambient light levels: sets isRoomLit if light enough to be in use.
; Leaves current light level in tempB0 (255 is maximum light level, 0 is fully dark).
getRoomInUseFromLDR:
    ; Check light levels, setting isRoomLit 1 if light enough for activity in the room else 0, with some hysteresis.
    ; The system can use ambient light level to help guess occupancy; very dark (<13% of max) implies no active occupants.
    readadc INPUT_LDR, tempB0
    if tempB0 < LDR_THR_LOW then
        isRoomLit = 0
    else if tempB0 > LDR_THR_HIGH then
        isRoomLit = 1
    endif
    return




#endif
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

; ****** MCP79410-RTC-SPI-simple.inc.bas ****** in module library
; Basic support for MCP79410 1.8V--5.5V RTC, using I2C.
; Appendable PICAXE basic fragment.



; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol DS1306_CE_O ; output bit


; NOTE: 1Hz output signal appears to be high for the 1st half of each second (DHD20130318) and enabled by default (bit 2 in reg $f).


#rem
Typical hardware setup, eg with supercap, using 16-pin DIL version.

; I2C SCL to B.4 (p10 on 18M2+)
; I2C SDA to B.1 (p7 on 18M2+)
#endrem



#ifdef USE_MODULE_MCP79410_RTC_SIMPLE ; Only use content if explicitly requested.

; Set PICAXE as master and MCP79140 as (slow) slave.  (Can be fast/400KHz where V+ > 2.5V.)
MCP79410hi2setupSlow:
    hi2csetup i2cmaster, %11011110, i2cslow, i2cbyte
    return;

; Power-on initialisation.
; Sets up slow (100kHz) I2C bus.
; Ensures that clock is running and in 24h mode.
MCP79410InitSlowI2C:
    gosub MCP79410hi2setupSlow
    ; Start the clock if not already running...
    hi2cin 0,(B0)
    if bit7 = 0 then
        bit7 = 1
        hi2cout 0,(B0) ; Set the clock-run bit.
    endif
    ; Ensure that the RTC is in 24h mode.
    hi2cin 2,(B0)
    if bit6 != 0 then
        bit6 = 0
        bit5 = 0 ; Ensure valid hour remains...
        hi2cout 2,(B0)
    endif
    return

; Reads the seconds register (in BCD, from 0--$59) into B0.
; Minimal SPI interaction to do this, so reasonably quick.
; I2C bus must be correctly set up (eg MCP79410hi2setupSlow must have been called since start-up, or since another I2C device last used).
MCP79410ReadBCDSeconds:
    hi2cin 0,(B0)
    bit7 = 0 ; Hide clock-run bit if set.
    return

; Reads the hours and minutes registers (in BCD, 0--$23 and 0--$59) into B1 and B0 respectively.
; I2C bus must be correctly set up.
; I2C bus must be correctly set up (eg MCP79410hi2setupSlow must have been called since start-up, or since another I2C device last used).
MCP78410ReadBCDHoursMinutes:
    hi2cin 1,(B0,B1)
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
; DHD20130312: Using B0 versions of some SPI routines for performance.
; DHD20130309: only reading status reg 1 (#3) in FIFO TX, but also only terminating on ipksent (bit 2); may have fixed 32MHz unreliability problem.
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
    goto RFM22ModeStandby ; GOSUB CHAIN: gosub RFM22ModeStandby return ; For speed and to preserve gosub slots.


; Simple test that RFM22 seems to be correctly connected over SPI.
; Returns 0 in SPI_DATAB if RFM22 appears present and correct, else non-zero value for something wrong.
; tempB0 contains device type as read.
; tempB1 contains device version iff device type was read OK.
; Can be called before or after RFM22PowerOnInit.
; Destroys B0.
RFM22CheckConnected:
    B0 = 0 ; device type
    gosub RFM22ReadReg8BitB0
    tempB0 = B0
    if B0 != RFM22_SUPPORTED_DEVICE_TYPE then _RFM22CheckConnectedError
    B0 = 1 ; device version
    gosub RFM22ReadReg8BitB0
    tempB1 = B0
    if B0 != RFM22_SUPPORTED_DEVICE_VERSION then _RFM22CheckConnectedError
    SPI_DATAB = 0 ; All OK.   ; FIXME: change API to return status in B0.
    return
; Error return.
_RFM22CheckConnectedError:
    SPI_DATAB = 1 ; Error value
    return

; Set up a block of RFM22 registers from EEPROM.
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
    gosub SPI_shiftin_byte_MSB_preclB0
    tempB2 = B0
    gosub SPI_shiftin_byte_MSB_preclB0
    SPI_DATAB = B0 ; FIXME: change API to skip this
    high RFM22_nSEL_O
    return

; Read/discard status (both registers) to clear interrupts.
; Destroys SPI_DATAB.
RFM22ClearInterrupts:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftout_0byte_MSB_pre ; read and discard status 1 quickly.
    gosub SPI_shiftout_0byte_MSB_pre ; read and discard status 2 quickly.
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
    ; Disable all interrupts by (burst) writing 0 to both interrupt-enable registers.  (May help radio power down fully.)
    low RFM22_nSEL_O
    B0 = RFM22REG_INT_ENABLE1
    gosub SPI_shiftout_byte_1MSB_preclB0
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    ; Clear any pending interrupts.  FIXME: may need to be done after disabling ints to avoid races?
    goto RFM22ClearInterrupts ; GOSUB CHAIN: gosub RFM22ClearInterrupts return ; For speed and to preserve gosub slots.

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

#rem
; Enter 'tune' mode (to enable fast transition to TX or RX mode).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTune:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000010 ; PLLON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.
#endrem

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

#rem
; Append a single byte to the transmit FIFO.
; Does not check for or prevent overflow.
; Byte to write should be in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteByteToTXFIFO:
    SPI_DATAB = RFM22REG_FIFO
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.
#endrem

; Transmit contents of on-chip TX FIFO: caller should revert to low-power standby mode (etc) if required.
; Destroys tempB0, tempB1, tempB2, B0.
; If SPI_DATAB != 0 on exit then packet apparently sent correctly/fully.
; Does not clear TX FIFO (so possible to re-send immediately).
; Note: Reliability possibly helped by early move to 'tune' mode to work other than with default (4MHz) lowish PICAXE clock speeds.
RFM22TXFIFO:
    ;gosub RFM22ModeTune ; Warm up the PLL for quick transition to TX below (and ensure NOT in TX mode).
    ; Enable interrupt on packet send ONLY.
    SPI_DATAB = RFM22REG_INT_ENABLE1
    tempB2 = 4
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_INT_ENABLE2
    gosub RFM22WriteReg8Bit0
    gosub RFM22ClearInterrupts ; Clear any current status...
    gosub RFM22ModeTX ; Enable TX mode and transmit TX FIFO contents.

    ; Each byte in the FIFO takes 1.6ms at 200us/bit, so max 102.4ms for full 64-byte payload.
    ; Whole TX likely to take > 70ms for a typical FHT8V message; avoid bashing SPI too hard!
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    for tempB1 = 0 to 64 ; Should be plenty of time even at max clock rate...
        pause 18 ; May be a fraction of nominal pause time if running at high clock speed.
#else
    for tempB1 = 0 to 8 ; Should be plenty of time even with some wobble on nap timer...
        nap 0 ; Save a little energy...
#endif
        B0 = RFM22REG_INT_STATUS1 ; Read just status reg 1 looking for bit 2 (ipksent) to be set...
        gosub RFM22ReadReg8BitB0
        if bit2 != 0 then exit ; Packet sent...
    next tempB1 ; Spin until packet sent...  COULD POLL INPUT PIN FROM nIRQ FIRST/INSTEAD.
    SPI_DATAB = bit2
    return

#rem
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
#endrem

; Reads a byte from a radio register over SPI.
; Register number in B0 on call (with msb / bit 7 = 0 for read).
; Result is returned in B0.
RFM22ReadReg8BitB0:
    low RFM22_nSEL_O
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftin_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a byte to a radio register over SPI.
; Register number in SPI_DATAB on call (will be destroyed); MSB is forced to 1 to enforce write mode.
; Data content to write in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit:
    low RFM22_nSEL_O
    B0 = SPI_DATAB
    gosub SPI_shiftout_byte_1MSB_preclB0
    B0 = tempB2
    gosub SPI_shiftout_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a zero byte to a radio register over SPI.  (Optimised common case.)
; Register number in SPI_DATAB on call (will be destroyed); MSB is forced to 1 to enforce write mode.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit0:
    low RFM22_nSEL_O
    B0 = SPI_DATAB
    gosub SPI_shiftout_byte_1MSB_preclB0
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
; Returns input data in B0 byte variable.
SPI_shiftin_byte_MSB_preclB0:
#ifdef REDUCE_CODE_SPACE
    gosub _SPI_sipost ; slightly less efficient, but saves a little space...
#else
    bit7 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit6 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit5 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit4 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit3 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit2 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit1 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit0 = SPI_SDI_PIN
#endif
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return

; SPI shift in (ie read) a single byte, most-significant bit first, data post-clock.
; Returns input data in B0 byte variable.
SPI_shiftin_byte_MSB_postclB0:
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
_SPI_sipost:
    bit7 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit6 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit5 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit4 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit3 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit2 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit1 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit0 = SPI_SDI_PIN
    return

; SPI shift out (ie write) a single byte, most-significant bit first with MSB forced to 1, data pre-clock.
; Sends output data from B0 byte variable.
; This 'MSB forced to 1' is useful for initiating write operations for SPI devices.
SPI_shiftout_byte_1MSB_preclB0:
    SPI_SDO_PIN = 1
    goto _SPI_shiftout_byte_1MSB_preclB

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
_SPI_shiftout_byte_1MSB_preclB:
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


; Dump byte in B0 (not altered) as two digit hex to serial.
; B1 is destroyed.
DiagSertxdHexByte:
    B1 = B0 / 16 + "0" ; High nybble.
    gosub _DiagSertxdHexNybble
    B1 = B0 & 15 + "0" ; Low nybble.
_DiagSertxdHexNybble:
    if B1 > "9" then : B1 = B1 + 7 : endif
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
    ; Nothing to see here, move along please...
#endif
