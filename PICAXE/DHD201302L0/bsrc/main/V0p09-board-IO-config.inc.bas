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
