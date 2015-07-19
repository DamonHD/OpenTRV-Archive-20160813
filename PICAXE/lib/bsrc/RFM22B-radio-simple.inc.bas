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