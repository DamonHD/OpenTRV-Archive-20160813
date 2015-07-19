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

; Test DS1306 is behaving sanely.

#picaxe 18M2

#define USE_MODULE_DS1306RTCSPISIMPLE
#define USE_MODULE_SPISIMPLE

; C.6: SPI serial protocol data input
symbol SPI_SDI = C.6
symbol SPI_SDI_PIN = input6    ; C.6
input C.6

; B.2: SPI clock (output).
symbol SPI_SCLK_O = B.2
output B.2
; B.3: SPI data (output).
symbol SPI_SDO = B.3
symbol SPI_SDO_PIN = outpinB.3     ; SPI data (output) in pinX.Y format.
output B.3

; B.6: DS1306 RTC active high Chip Enable for SPI
symbol DS1306_CE_O = B.6
low DS1306_CE_O ; make inactive ASAP


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



; B16
; SPI routines usually read/write byte to/from here.
symbol SPI_DATAB = b16



; Main loop; never exits.
do
    gosub DS1306ReadBCDSecondsB0
    debug ; Watch the (BCD) seconds increment in B0...
    nap 4

loop ; end of main loop

