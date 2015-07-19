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

; Skeleton control loop for DHD201203 level-0 spec.
; DHD20130119

; For 18M2+ on AXE091
#picaxe 18M2

; Default 4MHz clock.
gosub setNormalClockSpeed

; Button manual toggle between 'off'/'frost' target of 5C and 'warm' target of ~18C
; (button may have to be held down for up to a few seconds to get the unit's attention),
; and acknowledgement is long flash in new mode (red is 'warm', green is frost).

; This generates one or two short flashes on a ~5s cycle.
; First flash is the operating mode as above (red is 'warm', green is frost).
; Second flash if present indicates "calling for heat" (red)
; or "temperature OK" (green) and cancelling call for heat.
; An absent second flash indicates bang-on target temperature and no commands being sent.

; If target is not being met then aim to turn TRV fully on and call for heat.
; Has a small amount of hysteresis to reduce short-cycling of the boiler.
; (Possibly do proportional TRV control as target temperature is neared to reduce overshoot.)

; This has a simple setback (drops the 'warm' target a little to save energy)
; using an LDR, ie ambient light, as a proxy for occupancy.

; Reasonably accurate loop timing may be necessary to keep in sync with receivers
; (eg on TRVs) that only have their radio on for a low duty cycle to save energy.
; Thus 'sleep' and 'nap' may have to be eschewed.
;
; This version assumes that the boiler and TRV transmissions can be sent at any time.
;
; IF DEFINED: in the absence of an RTC, and to keep sync with remote devices, keep on-chip elapsed time measure as good as possible.
;#define KEEP_ELAPSED_TIME_ACCURATE


; No RTC required.


; KEY CONSTANTS
; Frost (minimum) temperature.
symbol FROST = 5
; Target comfort room temperature.
symbol WARM = 19
; Setback degrees (non-negative).
symbol SETBACK = 1

; INPUT SENSORS
; Momentary button to toggle between off and warm modes (logic-level input).
symbol BUTTON_MODE = C.1
input BUTTON_MODE
; LDR light sensor (ADC input); higher voltage indicates more light.
symbol LDR = C.0
; Temperature sensor (1-wire).
symbol TEMP_SENSOR = C.7

; OUTPUT INDICATORS
; Green 'temp OK' LED.  (LED1 on AXE091, B.1 on 18M2)
symbol LED_TEMPOK = B.1
; Red 'calling for heat' LED.  (LED3 on AXE091, B.3 on 18M2)
symbol LED_HEATCALL = B.3


;-----------------------------------------
; GLOBAL VARIABLES
; B0 & B1 (AKA W0) as booleans
; Boolean flag 1/true if was calling for heat last time.
symbol wasCallingForHeat = bit0
; Boolean flag 1/true if in 'warm' mode (0 => 'frost' mode).
symbol isWarmMode = bit1
; Boolean flag 1/true if room appears in use.
symbol isRoomInUse = bit2;

; B2 & B3 (AKA W1) & W2
; Current target temperature in C, initially 'frost' protection only.
symbol targetTempC = b2;
let targetTempC = FROST;
; Current temperature in C (note that -ve would show as very positive, but we'll ignore that)
symbol currentTempC = b3
; Full precision temperature in C x 16 as a word.
symbol currentTempC16 = w2;

; W3 (AKA B6 & B7) as X10 output command word
; Word sent over X-10 on request.
symbol X10WordOut = w3;
; X10 command to turn on the boiler on.
symbol X10BoilerOn  = %0110000000000000 ; A1 ON
; X10 command to turn on the boiler off.
symbol X10BoilerOff = %0110000000100000 ; A1 OFF

; B8 (aka part of W4)
; Current TRV value percent open (0--100 inclusive).
symbol TRVPercentOpen = b8;

; B10 & B11 (aka  W5)
; Temp/scratch bytes 0 & 1.  Not expected to survive subroutine calls, etc.
symbol tempB0 = b10;
symbol tempB1 = b11;
;-----------------------------------------


; Main loop; never exits.
do
    ; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
    gosub getTemp
    
	; Check occupancy, setting isRoomInUse 1 if activity else 0.
    gosub getOccupancy

    ; Indicate/adjust mode.
    ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
    ; Uses button held down to toggle isWarmMode state.
    ; (System starts in 'frost' state.)
    gosub showOrAdjustMode
    
    ; Select target temperature based on mode and occupancy.
    if isWarmMode = 0 then
        targetTempC = FROST
    else
        if isRoomInUse = 1 then
            targetTempC = WARM
        else 
            targetTempC = WARM - SETBACK ; must never be below FROST
        end if
    end if

    ; Call for heat if below target temperature and show 'call for heat' status
    ; else if over target then cancel any call for heat and show 'temperature OK' status.
    ; Includes hysteresis around the target temperature to reduce cycling.
    if currentTempC < targetTempC then
        gosub callforheat
    else if currentTempC > targetTempC then
        gosub cancelcallforheat
        wasCallingForHeat = 0
    else
        ; If on target temperature then don't send any commands and don't flash the status LEDs.
    end if


    ;sertxd("T=",#currentTempC,"C, target=",#targetTempC,"C",13,10)
    
    
    ; Sleep in lowest-power mode that we can for as long as we reasonably can.
    ; (User has to hold button down one cycle to flip mode, and blocking new program download would be bad.)
    ; Sleep with all LEDs off.
    ;low LED_TEMPOK
    ;low LED_HEATCALL
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 5000
#else
	disablebod
	sleep 2
    enablebod
#endif

loop


; Set the default clock speed.
setNormalClockSpeed:
    setfreq m4
    return


showOrAdjustMode:
    ; Indicate/adjust mode.
    ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
    ; Uses button held down to toggle isWarmMode state.
    ; (System starts in 'frost' state.)
    if pinC.1 = 1 then
        if isWarmMode = 0 then
            isWarmMode = 1
            high LED_HEATCALL    ; long flash 'heat call' to indicate warm mode.
            gosub bigPause
            low LED_HEATCALL
        else
            isWarmMode = 0
            high LED_TEMPOK      ; long flash 'temp OK' to indicate frost mode.
            gosub bigPause
            low LED_TEMPOK
        end if
    else ; indicate current mode with flash
        if isWarmMode = 0 then
            high LED_TEMPOK      ; flash 'temp OK' to indicate frost mode.
            gosub tinyPause
            low LED_TEMPOK
        else
            high LED_HEATCALL    ; flash 'heat call' to indicate heating mode.
            gosub tinyPause
            low LED_HEATCALL
        end if
    end if
    gosub mediumPause ; pause before next flash (if any)
    return

 
; Take a tiny pause, saving power if possible without losing timing accuracy.
tinyPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 32
#else
    nap 1
#endif
    return
; Take a medium pause, saving power if possible without losing timing accuracy.
mediumPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 72
#else
    nap 2
#endif
    return
; Take a significant pause, saving power if possible without losing timing accuracy.
bigPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 576
#else
    nap 5
#endif
    return


getTemp:
    ; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
    readtemp12 TEMP_SENSOR, currentTempC16
    currentTempC = currentTempC16 / 16 ; Convert without rounding (ie truncate).
    ; Force negative temperature to 0 to simplify processing.
    if currentTempC >= 128 then
        currentTempC = 0;
        currentTempC16 = 0;
    end if
    return
    
    
getOccupancy:
	; Check occupancy, setting isRoomInUse 1 if activity else 0.
    ; Look at light level to help guess occupancy; very dark (<10% of max) implies not active occupants.
    readadc LDR, tempB0
    if tempB0 < 25 then
        isRoomInUse = 0
    else
        isRoomInUse = 1
    end if
    return
    

; Flash 'heat call' LED, open up TRV, switch on boiler.
callforheat:
    high LED_HEATCALL ; flash to indicate call for heat
    gosub tinyPause
    low LED_HEATCALL
    
    ; Open TRV value first (as needed) usually all the way...
    TRVPercentOpen = 100
    gosub TRVAdjust
    
    ; ... then call for heat at the boiler.
    X10WordOut = X10BoilerOn
    gosub X10Send
    
    wasCallingForHeat = 1
    return


; Flash 'temp OK' LED, shut TRV, switch off boiler (if no one else is calling for heat).
cancelcallforheat:
    high LED_TEMPOK
    gosub tinyPause
    low LED_TEMPOK
   
    ; Cancel call for heat at boiler first...
    X10WordOut = X10BoilerOff
    gosub X10Send
    
    ; ... then shut off TRV.
    TRVPercentOpen = 0
    gosub TRVAdjust

    wasCallingForHeat = 0
    return


; Sends X10WordOut.
; Based on J C Burchell version 1.0 2009 code at https://docs.google.com/document/pub?id=1dF5rpRkv-Ty3WcXs8D9Oze86hR50ZI96RzNrMvd_S0U
; Runs overspeed to meet timing constraints.
X10Send:
	setfreq m32
	
	; TODO
	
	gosub setNormalClockSpeed
    return


; Sends 'percentage open' in TRVPercentOpen command to TRV.
; May treat any non-zero value as 100%.
TRVAdjust:

    ; TODO
    
    return;