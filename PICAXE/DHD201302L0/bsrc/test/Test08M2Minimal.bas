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

; Hugely simplified version of boiler control loop on 08M2+
#picaxe 08m2

symbol OUT_BOILER = C.4;
output OUT_BOILER
low OUT_BOILER
symbol OUT_LED = C.1;
output OUT_LED
low OUT_LED

symbol IN_TEMP = C.2;
input C.2;

; Indicate start-up
high OUT_LED
nap 0
low OUT_LED
nap 2

; MAIN LOOP, runs a little less than once per minute.
do
    readtemp IN_TEMP, b0
    if b0 < 19 then
        gosub boilerOn
    else
        gosub boilerOff
    end if
    sleep 30
loop

end


; Turn the boiler on.
boilerOn:
    high OUT_BOILER
    high OUT_LED
    ;nap 2
    ;low OUT_LED
    return

; Turn the boiler off.
boilerOff:
    low OUT_BOILER
    ;high OUT_LED
    ;nap 0
    low OUT_LED
    return