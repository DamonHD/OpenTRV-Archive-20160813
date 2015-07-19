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

; Test low-level SPI access from 18M2+.

#picaxe 18M2

#define USE_MODULE_SPISIMPLE ; Use/test low-level SPI support.


symbol SPI_SCLK_O = B.2			; SPI clock (output) 18M2 p8
symbol SPI_SDI = C.6			; SPI data (input) C.6 18M2 p15
symbol SPI_SDI_PIN = input6		; SPI data (input) in inputX format
symbol SPI_SDO = B.3			; SPI data (output) 18M2 p9
symbol SPI_SDO_PIN = outpinB.3	; SPI data (output) in outpinX.Y format.
symbol SPI_DATAB = b8			; SPI write byte from here and read byte to here
symbol tempB0 = b14			    ; temp working variable
symbol tempB1 = b15 		 	; temp working variable

symbol RFM22_nSEL_O = B.5; 18M2 p11


; Main loop; never exits.
do
    gosub SPI_init

    low RFM22_nSEL_O
    SPI_DATAB = 0 ; device type
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    b4 = SPI_DATAB
    high RFM22_nSEL_O

    low RFM22_nSEL_O
    SPI_DATAB = 1 ; device version
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    b5 = SPI_DATAB
    high RFM22_nSEL_O

    low RFM22_nSEL_O
    SPI_DATAB = 2 ; device status
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    b6 = SPI_DATAB
    high RFM22_nSEL_O
    
    debug

	nap 4

loop ; end of main loop

