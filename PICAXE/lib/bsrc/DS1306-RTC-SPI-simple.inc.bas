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