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

; Test LDR behaviour with 18M2+.

#picaxe 18M2

;#define USE_MODULE_LDROCCUPANCYDETECTION ; Use/test low-level SPI support.


; C.0: LDR light sensor (ADC input); higher voltage indicates more ambient light.
symbol INPUT_LDR = C.0



; Main loop; never exits.
do
    readadc INPUT_LDR, B0
    debug
    sleep 2

loop ; end of main loop

