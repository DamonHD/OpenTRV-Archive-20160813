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

; Check behaviour of internal temp sensor.


; For 18M2+ on AXE091 ***with 5V regulated supply***.
#picaxe 18M2


; INPUT SENSORS
; Temperature sensor (1-wire).
symbol TEMP_SENSOR = C.7
input TEMP_SENSOR


; Main loop; never exits.
do
    ; Real MacKoy; temp in 16ths of 1C.
    readtemp12 TEMP_SENSOR, w0
    w1 = w0 / 16 ; Convert to C.
    
    ; Flakey internal temperature measure...
    readinternaltemp IT_5V0, 0, w2
    w3 = w2 / 16 ; Convert to C.
    
    debug
    sleep 5

loop ; end of main loop

