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

; Test access to MCP79140 RTC using I2C from 18M2+.
; For 18M2+ on AXE091 ***with 5V regulated supply***.


; I2C SCL to B.4 (p10 on 18M2+)
; I2C SDA to B.1 (p7 on 18M2+)

#picaxe 18M2

        hi2csetup i2cmaster, %11011110, i2cfast, i2cbyte ; Set PICAXE as master and MCP79140 slave.  (Can be fast/400KHz where V+ > 2.5V.)

        ; Start the clock if not already running...
        hi2cin 0,(B0)
        if bit7 = 0 then
            bit7 = 1
            hi2cout 0,(B0) ; Set the clock-run bit.
        endif

        ; Enable 1Hz output on MFP.
        hi2cout 7,($40)

; Main loop; never exits.
do

    ; Read the clock time
    hi2cin 0,(B0,B1,B2,B3,B4,B5,B6,B7) ; ss, mm, hh, weekday + ctrl, dd, mm, yy, control reg

    ; Report time.
    debug ; may interfere with elapsed time measurement

    pause 500

loop ; end of main loop

