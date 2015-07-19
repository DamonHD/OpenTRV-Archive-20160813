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