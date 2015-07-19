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

; ****** LDROccupancyDetection.inc.bas ****** in module library
; Simple occupancy detection using ambient light levels.
; Appendable PICAXE basic fragment.

; RECENT CHANGES
; DHD20130301: Added optional LDR_EXTRA_SENSITIVE for LDR not exposed to direct light to boost sensitivity.
; DHD20130225: Changed global this sets to "isRoomLit" and also uses it to provide hysteresis.
; DHD20130221: Bumped threshold up a little to 33 (~13%) based on observations.


; Dependencies:
; INPUT_LDR ADC input pin symbol must be defined with LDR to +V and pull-down to 0V (so more light gives higher value).
; #ifdef LDR_EXTRA_SENSITIVE (optional) ; Define this if LDR not exposed to much light, eg behind a grille.
; isRoomLit bit symbol must be defined; will be set to 1 if room is light enough for occupancy/activity, 0 otherwise.
; tempB0 temporary byte symbol must be defined; will be used/overwritten.
; #ifdef OMIT_MODULE_LDROCCUPANCYDETECTION suppresses inclusion of module code.

; Using techsupplies.co.uk SEN002 (like GL5528 1M+ dark, ~10k @ 10 Lux) with fixed pull-down resistor.
; Works OK with 10k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (5V) at threshold of 25 (~10% max).
; Works OK with 100k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (3.3V) at threshold of 25 (~10% max).  ("Dark" at night ~5.)



#ifdef USE_MODULE_LDROCCUPANCYDETECTION ; Only use content if explicitly requested.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION

#ifdef LDR_EXTRA_SENSITIVE ; Define if LDR not exposed to much light.
symbol LDR_THR_LOW = 5
symbol LDR_THR_HIGH = 8
#else ; Normal settings.
symbol LDR_THR_LOW = 30
symbol LDR_THR_HIGH = 35
#endif


; Attempts to detect potential room use/occupancy from ambient light levels: sets isRoomLit if light enough to be in use.
; Leaves current light level in tempB0 (255 is maximum light level, 0 is fully dark).
getRoomInUseFromLDR:
    ; Check light levels, setting isRoomLit 1 if light enough for activity in the room else 0, with some hysteresis.
    ; The system can use ambient light level to help guess occupancy; very dark (<13% of max) implies no active occupants.
    readadc INPUT_LDR, tempB0
    if tempB0 < LDR_THR_LOW then
        isRoomLit = 0
    else if tempB0 > LDR_THR_HIGH then
        isRoomLit = 1
    endif
    return




#endif
#endif