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

; From AN440: The output power is configurable from +13 dBm to Ð8 dBm (Si4430/31), and from +20 dBM to Ð1 dBM (Si4432) in ~3 dB steps. txpow[2:0]=000 corresponds to min output power, while txpow[2:0]=111 corresponds to max output power.
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