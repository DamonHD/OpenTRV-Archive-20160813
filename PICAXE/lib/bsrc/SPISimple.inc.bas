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