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