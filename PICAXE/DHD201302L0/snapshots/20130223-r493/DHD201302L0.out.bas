
; GENERATED/OUTPUT FILE: DO NOT EDIT!
; Built 2013/23/02 08:33.
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

; TRV (and boiler-node) control loop for DHD201203 level-0 spec.

;-----------------------------------------
; UI DESCRIPTION
; Button manual toggle between 'off'/'frost' target of 5C and 'warm' target of ~18C
; (button may have to be held down for up to a few seconds to get the unit's attention),
; and acknowledgement is long/medium flash in new mode (long is 'warm', medium is frost).

; The unit generates one or two short flashes on a few-second cycle.
; Optional tiny first flash indicates 'warm mode'.
; A second flash if present indicates "calling for heat".

; If target is not being met then aim to turn TRV on/up and call for heat from the boiler too,
; else if target is being met then turn TRV off/down and stop calling for heat from the boiler.
; Has a small amount of hysteresis to reduce short-cycling of the boiler.
; Does some proportional TRV control as target temperature is neared to reduce overshoot.

; This can use a simple setback (drops the 'warm' target a little to save energy)
; eg using an LDR, ie reasonable ambient light, as a proxy for occupancy.


; RECENT CHANGES
; DHD20130222: enabled RTC to improve timing (NB: setup check spotted missing CE connection on stripboard!).
; DHD20130221: added 0xaaaaaaaa RFM22B-friendly pre-preamble at Mike Stirling's suggestion.
; DHD20130218: freed up B.1 and B.4 to allow use of i2c peripherals, relocating LED_HEATCALL from B.1 to B.7. (r417)
; DHD20130218: currently assumes presence of DS18B20 1-wire temp sensor, but only good down to 3V so may need to be able to use alternative.
; DHD20130212: for now transmits every second to be heard by FHT8V TRV, wasting energy, etc!



;-----------------------------------------
; GLOBAL CONFIGURATION
; Select which hardware and software modules are available and to be used,
; and provide any necessary static configuration for those modules.

; For 18M2+
#picaxe 18M2

; IF DEFINED: this unit will act as boiler-control hub listening to remote thermostats, possibly in addition to controlling a local TRV.
;#define BOILER_HUB

; IF DEFINED: this unit will act as a thermostat controlling a local TRV (and calling for heat from the boiler).
#define LOCAL_TRV
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.


; IF DEFINED: use simple LDR-based detection of room use/occupancy; brings in getRoomInUseFromLDR subroutine.
#define USE_MODULE_LDROCCUPANCYDETECTION

; IF DEFINED: use DS1306 RTC for accurate elapsed time measures at least.
#define USE_MODULE_DS1306RTCSPISIMPLE





;-----------------------------------------
; Derived config: don't edit unless you know what you are doing!
#ifdef LOCAL_TRV
; IF DEFINED: use RFM22 radio transceiver over SPI.
#define USE_MODULE_RFM22RADIOSIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
; IF DEFINED: use simple FHT8V TX code.
#define USE_MODULE_FHT8VSIMPLE_TX
#endif

#ifdef BOILER_HUB
; IF DEFINED: use RFM22 radio transceiver over SPI.
#define USE_MODULE_RFM22RADIOSIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
; IF DEFINED: use simple FHT8V RX code.
#define USE_MODULE_FHT8VSIMPLE_RX
#endif

#ifdef USE_MODULE_DS1306RTCSPISIMPLE
; Requires SPISimple module.
#define USE_MODULE_SPISIMPLE
#else
; IF DEFINED: in the absence of an RTC, and to keep sync with remote devices, keep on-chip elapsed time measure as good as possible.
#define KEEP_ELAPSED_TIME_ACCURATE ; Avoid any use of sleep, nap, etc, that stops or otherwise interferes with 'time' on 18M2+.
#define TIME_LSD_IS_BINARY ; Units of TIME_LSD is seconds wrapping at $ff (else will be BCD $00 to $59).
#endif



;-----------------------------------------
; MAIN GLOBAL CONSTANTS
; Frost (minimum) temperature in degrees C.
symbol FROST = 5
; Default warm/comfort room temperature in degrees C.
symbol WARM = 18
; Initial setback degrees C (non-negative).  Note that 1C setback may result in ~8% saving in UK.
symbol SETBACK = 1
; Full setback degrees C (non-negative).  Should result in significant automatic energy savings if engaged.
symbol SETBACK_FULL = 3
; Prolonged inactivity time deemed to indicate room really unoccupied to trigger full setback (minutes).
symbol SETBACK_FULL_MINS = 30



;-----------------------------------------
; INPUTS / SENSORS (primarily)
; ---- C PINS ----  (can include some outputs)
dirsC = %00000000 ; All inputs.

#ifdef USE_MODULE_LDROCCUPANCYDETECTION
; C.0: LDR light sensor (ADC input); higher voltage indicates more ambient light.
symbol INPUT_LDR = C.0
#endif

; C.1: Momentary button active high to toggle between off and warm modes (logic-level input).
symbol BUTTON_MODE = input1 ; C.1

#ifdef USE_MODULE_RFM22RADIOSIMPLE
; C.2: Active low to indicate interrupt from RFM22 (input from radio module).  Optional, else status will be polled in s/w.
; Pulled high, so can be left as input or set to high output.
;#define RFM22_nIRQ_I_PIN input2
;#define RFM22_nIRQ_I = C.2
#endif

; C.3/C.4: RESERVED: (C.4 serial in, C.3 serial out, eg on AXE091 board, for 18M2+.)

; C.5 UNALLOCATED
; C.5 is reset on 18X parts, but not on 18M2.
; Pulled high, so can be left as input or set to high output.

#ifdef USE_MODULE_SPISIMPLE
; C.6: SPI serial protocol data input
symbol SPI_SDI = C.6
symbol SPI_SDI_PIN = input6    ; C.6
;input C.6
#endif

; C.7: Temperature sensor (1-wire).
symbol TEMP_SENSOR = C.7

;-----------------------------------------
; OUTPUTS (primarily)
; ---- B PINS ---- (can include some inputs)
dirsB = %11111111 ; Set outputs where there is no conflict.  Stops pins floating and wasting power.
;pullup %00010010 ; Weak pullups for i2c lines (B.4 & B.1) in case external pull-ups not fitted to avoid floating.

; B.0: Direct DC active high output to call for heat, eg via SSR.
symbol OUT_HEATCALL = B.0
low OUT_HEATCALL ; send low ASAP

; B.1 i2c SDA on 18M2: RESERVED for now.
; Will be pulled up so can be inputs or high outputs (to avoid floating) for now.
high B.1

#ifdef USE_MODULE_SPISIMPLE
; B.2: SPI clock (output).
symbol SPI_SCLK_O = B.2
output B.2
; B.3: SPI data (output).
symbol SPI_SDO = B.3
symbol SPI_SDO_PIN = outpinB.3     ; SPI data (output) in pinX.Y format.
output B.3
#endif

; B.4: i2c SCL on 18M2: RESERVED for now.
; Will be pulled up so can made inputs or high outputs (to avoid floating) for now.
high B.4

#ifdef USE_MODULE_RFM22RADIOSIMPLE
; B.5: RFM22 radio active low negative select.
symbol RFM22_nSEL_O = B.5
high RFM22_nSEL_O ; make inactive ASAP
#endif

#ifdef USE_MODULE_DS1306RTCSPISIMPLE
; B.6: DS1306 RTC active high Chip Enable for SPI
symbol DS1306_CE_O = B.6
low DS1306_CE_O ; make inactive ASAP
#endif

; B.7: Red active high 'calling for heat' LED and other UI.
symbol LED_HEATCALL = B.7
high LED_HEATCALL ; Send high ASAP during initialisation to show that something is happening...


;-----------------------------------------
; GLOBAL VARIABLES
; B0, B1, B2 (aka W0 and bit0 to bit23) reserved as working registers for bit manipulation.

; B3 as persistent global booleans
; Boolean flag 1/true if in 'warm' mode (0 => 'frost' mode).
symbol isWarmMode = bit24
isWarmMode = 0 ; Start up not calling for heat.
; Boolean flag 1/true if room appears in use.
symbol isRoomInUse = bit25
isRoomInUse = 1 ; Start up assuming that the room is in use / occupied.
;
; Boolean temporary.
symbol tempBit0 = bit31

; B4 (aka part of W2)
; Current TRV value percent open (0--100 inclusive) and boiler heat-demand level.
; Anything other than zero may be treated as 100 by boiler or TRV.
symbol TRVPercentOpen = b4

; B5 (aka part of W2): job priority task n pending at each level (MSB highest pri) if bit 1.
; A zero value implies no jobs pending currently.
symbol jobsPending = b5
jobsPending = 0 ; No jobs pending initially...
; Code in loop body should be ordered to map priority here.
symbol MASK_JP_FS20 = %10000000 ; FS20 TX (highest because of timing tightness)
symbol MASK_JP_UI   = %01000000 ; UI (nearly highest for responsiveness)
symbol MASK_JP_TEMP = %00100000 ; Temperature read
symbol MASK_JP_OLDR = %00010000 ; Occupancy sensing with LDR
symbol MASK_JP_HTCL = %00001000 ; Heat call to boiler, wired and wireless; lower pri than sensors to happen only when they are done.

; B6 & B7 (AKA W3) & W4 (B8 & B9)
; Current target temperature in C, initially 'frost' protection only.
symbol targetTempC = b6
let targetTempC = FROST
; Current temperature in C (note that -ve would show as very positive, but we'll ignore that)
symbol currentTempC = b7
; Full precision temperature in C x 16 as a word.
symbol currentTempC16 = w4

; B10 & B11 (aka W5)
; Temp/scratch bytes 0 & 1 and OVERLAID temp word 0.  Not expected to survive subroutine calls, etc.
symbol tempB0 = b10
symbol tempB1 = b11
symbol tempW0 = w5
; B12 & B13 (aka W6)
; Temp/scratch bytes 2 & 3 and OVERLAID temp word 1.  Not expected to survive subroutine calls, etc.
symbol tempB2 = b12
symbol tempB3 = b13
symbol tempW1 = w6

; W7 (aka B14 & B15)
; Current semi-random word value to help with anti-collision algorithms, etc.
; Will not contain much entropy, and may be updated only once per major cycle.
symbol randWord = w7
symbol randMSB = b14
symbol randLSB = b15

#ifdef USE_MODULE_SPISIMPLE
; B16
; SPI routines usually read/write byte to/from here.
symbol SPI_DATAB = b16
#endif

; B17
; Least-significant digits of time, as captured at start of each loop iteration.
; Units are seconds, and may be binary (#ifdef TIME_LSD_IS_BINARY) else BCD, typically depending whether an RTC is being used.
; In binary this runs from 0 to $ff (continuous), in BCD from 0 to $59 (discontinuous).
symbol TIME_LSD = b17

; B18 & B19 (aka W9)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).
#endif

; TX/RX scratchpad block...
symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area.
symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.



; EEPROM allocation: some allocated spaces may not be used.
#ifdef USE_MODULE_RFM22RADIOSIMPLE
symbol FHT8V_RFM22_Reg_Values = 8 ; Start address in EEPROM for RFM22B register setup values for FHT8: seq of (reg#,value) pairs term w/ $ff reg#.
#endif



;-----------------------------------------
; INITIALISATION
; Do minimal 'safe' I/O setup ASAP.

; Default/normal 4MHz clock.
gosub setNormalClockSpeed

; SPI setup, if any.
#ifdef USE_MODULE_SPISIMPLE
gosub SPI_init
#endif

; Radio setup, if any.
#ifdef USE_MODULE_RFM22RADIOSIMPLE
; Reset and go into low-power mode.
gosub RFM22PowerOnInit
; Panic if not working as expected...
gosub RFM22CheckConnected
if SPI_DATAB != 0 then panic
; Block setup of registers, once.
tempB0 = FHT8V_RFM22_Reg_Values
gosub RFM22RegisterBlockSetup
; Standby mode.
gosub RFM22ModeStandby
#endif

; RTC setup, if any.
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
gosub DS1306ReadBCDSeconds
; Panic if RTC not connected (typically read $ff) or not otherwise responding appropriately.
if SPI_DATAB > $59 then panic
#endif

toggle LED_HEATCALL

; Get initial environmental readings before the main loop starts so all values are valid.
; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
gosub getTemperature
; Get ambient light level, if module present.
#ifdef USE_MODULE_LDROCCUPANCYDETECTION
gosub getRoomInUseFromLDR
#endif
; Update targets, etc, to be sensible before main loop starts.
gosub computeTargetAndDemand

toggle LED_HEATCALL

; Initialise the 'random' generator, in part from environmental inputs just collected.
gosub seedRandWord

low LED_HEATCALL ; Send low after initialisation finished.


;-----------------------------------------
; MAIN LOOP: never exits.
;
; Should cycle each second, generally aligned to elapsed time,
; and subroutines called from it should take less than 1 second to run.
;
; In general this also implies that it may only be possible
; to call do one small action on each cycle rather than many/all in each cycle.
;
; This uses approximately a minute (60 or 64-second) master cycle to spread slow operations through,
; and to help ensure that boiler/TRV cycles are no shorter than about 1 minute also.
do
    ; FIXME: until it is possible to correctly schedule transmission to FHT8V, send it EVERY second.
    gosub TRVAdjust

    ;debug ; Can be a handy spot to inspect memory...

    ; If no jobs then go back to sleep ASAP...
    if jobsPending = 0 then goto schedule

    ; Show loop body starting (the longer the flash, the busier the system)...
    ;high LED_AUX

    ; Deal with top-priority pending task only.
    ; Code order has to match the mask value/order.

#ifdef USE_MODULE_FHT8VSIMPLE_TX
    tempB0 = jobsPending & MASK_JP_FS20
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_FS20 ; Clear the pending status
        ; TODO
        goto schedule
    end if
#endif

    tempB0 = jobsPending & MASK_JP_UI
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_UI ; Clear the pending status
        ; Indicate/adjust mode.
        ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
        ; Uses button held down to toggle isWarmMode state. (System starts in 'frost' state.)
        ; Schedules update to TVR and boiler ASAP on change of mode, for user responsiveness.
        gosub pollShowOrAdjustMode
        ; Update internal target/demand values.
        gosub computeTargetAndDemand
        ; Display representation of internal heat-demand value.
        if TRVPercentOpen != 0 then
            gosub mediumPause ; Pause before 'calling for heat' flash.
            high LED_HEATCALL ; flash
            gosub tinyPause ; Sum of pauses must not take more than 1s slot time...
            low LED_HEATCALL
        end if
        goto schedule
    end if

    tempB0 = jobsPending & MASK_JP_TEMP
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_TEMP ; Clear the pending status
        ; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
        gosub getTemperature ; Very slow with DS18B20 (~700ms).
        ; Update internal target/demand values.
        gosub computeTargetAndDemand
        goto schedule
    end if

#ifdef USE_MODULE_LDROCCUPANCYDETECTION
    tempB0 = jobsPending & MASK_JP_OLDR
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_OLDR ; Clear the pending status
        ; Check occupancy, setting isRoomInUse 1 if activity else 0.
        gosub getRoomInUseFromLDR
        ; Update internal target/demand values.
        gosub computeTargetAndDemand
        goto schedule
    end if
#endif

    tempB0 = jobsPending & MASK_JP_HTCL
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_HTCL ; Clear the pending status
        if TRVPercentOpen = 0 then ; Stop calling for heat.
            low OUT_HEATCALL
        else ; Call for heat at the boiler if any demand at all.  (TODO: modulating!)
            high OUT_HEATCALL
        end if
        goto schedule
    end if

    ; Clear unserviceable job; shouldn't really happen...
    jobsPending = 0

schedule: ; Do general job scheduling (quickly) just before the end of the loop.

    ; Schedule UI interaction regularly (every even second, whether time in binary or BSD).
    tempB0 = TIME_LSD & 1
    if tempB0 = 0 then
        jobsPending = jobsPending OR MASK_JP_UI
    end if

    ; Schedule slow/occasional/non-time-critical tasks over a major cycle (just more than a minute).
    ; Note that if multiple jobs are queued at once then lower-priority ones may slip back several seconds.
#ifdef TIME_LSD_IS_BINARY
    tempB0 = TIME_LSD & 63 ; close to a minute cycle, values from 0 to $3f.
#else
    tempB0 = TIME_LSD ; exactly a minute cycle, BCD values from $00 to $59.
#endif
    select case tempB0 ; Note: MUST use case values that work for BCD and binary...
        ; Gather input data at start of major cycle
        ; in time to talk to TVR and boiler shortly afterwards at the start of the next minute.
        ; Sensor input has higher priority than calling for heat,
        ; so will complete first delaying call for heat if necessary.
#ifdef USE_MODULE_LDROCCUPANCYDETECTION
        case 1 ; Schedule checking occupancy...
            jobsPending = jobsPending OR MASK_JP_OLDR
#endif
        case 3 ; Schedule getting the temperature...
            jobsPending = jobsPending OR MASK_JP_TEMP
        case 5,7 ; Schedule send to boiler a couple of times at/near the start of the major cycle.
            jobsPending = jobsPending OR MASK_JP_HTCL
    endselect

mainLoopCoda: ; Tail of main loop...

    ; Show loop body complete.
    ;low LED_AUX

    ; Sleep in lowest-power mode that we can for as long as we reasonably can,
    ; attempting to align the end of the cycle with the ticking over of wallclock seconds.
    ; Sleep with all LEDs off.
    ;low LED_TEMPOK, LED_HEATCALL

    ; Wait for elapsed time to roll...

    ;debug ; Can be a handy spot to inspect memory...

    do
        ; Capture elapsed time (and wait for it to roll over).
        ; As soon as the elapsed time rolls over, start new main loop.
        ; In the interrim, fill time with radio RX and/or energy saving sleeps and/or random number churn, ...
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
        gosub DS1306ReadBCDSeconds
        tempB0 = SPI_DATAB ; BCD seconds.
#else
        tempB0 = time ; Internal elapsed time measure least-significant byte (binary).
#endif
        if tempB0 != TIME_LSD then
            ; TODO if (masked) time roll to a smaller number trigger the minute counter; robust even if individual seconds get missed.
            TIME_LSD = tempB0
            exit
        endif

        ; TODO: listen/RX radio comms if appropriate

        ; Churn the random value to fill time and make it more randomy...  B^>
        random randWord

        ; Sleep/pause a little, saving energy if possible.
        ; May be able to sleep in longer chunks if NOT doing radio RX and NOT yet at half-second mark...
#ifdef KEEP_ELAPSED_TIME_ACCURATE
        pause 18
#else
        disablebod
        nap 0
        enablebod
#endif
    loop

loop ; end of main loop


;-----------------------------------------
; PANIC
; In case of hardware not working correctly stop doing anything difficult/dangerous
; while indicating distress to users and conserving power if possible.
panic:
    ; TODO: safely shut down radios, motors, etc...
#ifdef USE_MODULE_RFM22RADIOSIMPLE
    ; Reset and go into low-power mode.
    gosub RFM22PowerOnInit
#endif
    do
        high LED_HEATCALL
        nap 0
        low LED_HEATCALL
        nap 3
    loop


;-----------------------------------------
; SUPPORT CODE


; Initialise the 'random' generator from the input values and other things.
; This does not discard any current random state, but should add some entropy to it.
; There probably isn't much real entropy but we can for example use the environmental inputs.
seedRandWord:
    random randWord ; churn
    ; Fold in bits from the internal temperature sensor, and supply voltage!
    readinternaltemp IT_RAW_L, 0, tempW0
    randWord = randWord ^ tempW0
    random randWord ; churn
#ifdef USE_MODULE_LDROCCUPANCYDETECTION
    ; Read directly from LDR ADC (if present) to get as much noise as possible.
    readadc10 INPUT_LDR, tempW0
    randWord = randWord ^ tempW0
    random randWord ; churn
#endif
    randWord = randWord ^ time ; Elapsed time may have some wobble in it...
    random randWord ; churn
    ; Fold in full-resolution temperature hopefully already collected.
    randWord = randWord + currentTempC16;
    random randWord ; churn
    ; TODO: fold in some non-volatile state from EEPROM and maybe store back.
    random randWord ; churn
    return


; Set the default clock speed (with correct elapsed-time 'time' behaviour).
setNormalClockSpeed:
    setfreq m4
    return

; Set a high clock speed (that preserves the elapsed-time 'time' behaviour if KEEP_ELAPSED_TIME_ACCURATE).
; http://www.picaxe.com/BASIC-Commands/Advanced-PICAXE-Configuration/enabletime/
setHighClockSpeed:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    setfreq m16 ; As fast as possible while maintaining elapsed 'time' word correctly on 18M2+.
#else
    setfreq m32 ; As fast as possible for 18M2+.  TODO: Check OK at 1.8V.
#endif
    return


; Poll for user request to toggle frost/warm mode, and flash to indicate state.
; Schedule TX/update to TRV and boiler ASAP on mode change for user responsiveness.
pollShowOrAdjustMode:
    ; Indicate/adjust mode.
    ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
    ; Uses button held down to toggle isWarmMode state.
    ; (System starts in 'frost' state.)
    if BUTTON_MODE = 1 then ; MUST match with BUTTON_MODE symbol
        high LED_HEATCALL
        if isWarmMode = 0 then
            isWarmMode = 1
            gosub bigPause       ; long flash 'heat call' to indicate now in warm mode.
        else
            isWarmMode = 0
            gosub mediumPause    ; medium flash 'heat call' to indicate now in frost mode.
        end if
        low LED_HEATCALL
    else ; indicate current mode with flash
        if isWarmMode = 1 then
            high LED_HEATCALL    ; flash 'heat call' to indicate heating mode.
            gosub tinyPause
            low LED_HEATCALL
        end if
    end if
    return


; Take a tiny pause, saving energy if possible without losing system timing accuracy.
tinyPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 18
#else
    nap 0
#endif
    return

; Take a medium pause, saving energy if possible without losing system timing accuracy.
mediumPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 144
#else
    nap 3
#endif
    randWord = randWord ^/ time
    random randWord ; churn
    return

; Take a significant pause, saving energy if possible without losing system timing accuracy.
bigPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 288
#else
    nap 4
#endif
    randWord = randWord ^ time
    random randWord ; churn
    return


; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
getTemperature:
    readtemp12 TEMP_SENSOR, currentTempC16 ; Takes ~700ms.
    currentTempC = currentTempC16 / 16 ; Convert without rounding (ie truncate).
    ; Force negative temperature to 0 to simplify processing.
    if currentTempC >= 128 then
        currentTempC = 0;
        currentTempC16 = 0;
    end if
    return


; Compute target temperature and set heat demand for TRV and boiler.
; Inputs are isWarmMode, isRoomInUse.
; Values set are targetTempC, TRVPercentOpen.
; The inputs must be valid (and recent, ideally).
; This routine should be quick to execute; no I/O is done.
computeTargetAndDemand:
    ; Compute target.
    if isWarmMode = 0 then
        targetTempC = FROST
    else
        if isRoomInUse = 1 then
            targetTempC = WARM
        else
            targetTempC = WARM - SETBACK ; must never be below FROST
        end if
    end if

    ; Set heat demand with some hysteresis and a hint of proportional control.
    if currentTempC < targetTempC then
        TRVPercentOpen = 100
    else if currentTempC > targetTempC then
        TRVPercentOpen = 0;
    else
        ; TRVPercentOpen = 33 ; Default state if temperature OK...
        ; Use currentTempC16 lsbits to set valve percentage for proportional feedback
        ; to provide more efficient and quieter TRV drive and probably more stable room temperature.
        tempB0 = currentTempC16 & $f ; Only interested in lsbits.
        tempB0 = 16 - tempB0 ; Now in range 1 (at warmest end of 'correct' temperature) to 16 (coolest).
        TRVPercentOpen = tempB0 * 6 ; Now in range 6 to 96, eg valve nearly shut just below exceeding 'correct' temperature.
    end if
    return


; Sends 'percentage open' in TRVPercentOpen command to TRV.
; though sending intermediate values will almost certainly save TRV noise and wear and battery, and regulate temperature better.
; B0, tempB0, tempB1, SPI_DATAB are destroyed.
TRVAdjust:
#ifdef USE_MODULE_RFM22RADIOSIMPLE
    gosub setHighClockSpeed ; Turn on turbo mode else this takes >> 1s to run, which is way too slow!

    FHT8V_CMD = $26 ; Set valve to specified open fraction [0,255] => [closed,open].
    tempW0 = TRVPercentOpen * 255
    FHT8V_EXT = tempW0 / 100 ; Set valve open to desired %age.

    gosub FHT8VCommandQueueTXViaRFM22

    gosub setNormalClockSpeed ; Turn off turbo mode...

    ; Send it!
    gosub RFM22TXFIFO
#endif
    return
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
#undefine USE_MODULE_DS1306RTCSPISIMPLE ; Prevent duplicate use...

; Reads the seconds register (in BCD, from $00 to $59) into SPI_DATAB.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSeconds:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclock
    low DS1306_CE_O
    return

#endif
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

; ****** FHT8V-simple.inc.bas ****** in module library
; Basic support for FHT8V wireless electronic TRV over RFM22B radio.
; Appendable PICAXE basic fragment.
; TX, RX and I/O-free elements (eg for unit testing) can be enabled separately to preserve code space.

; Many thanks to Mike Stirling http://mikestirling.co.uk/2012/10/hacking-wireless-radiator-valves-with-gnuradio/
; for register settings, the 200us encoding, and lots of hand-holding!


; Dependencies (for USE_MODULE_FHT8VSIMPLE_TX, transmit side, no I/O)
; symbol ScratchMemBlock ; Start of contiguous scratch memory area (to assemble data to TX) < 0x100.
; symbol ScratchMemBlockEnd ; Inclusive end of scratch memory area, > ScratchMemBlock and < 0x100.
; symbol FHT8V_HC1 ; House code 1, constant or (byte) register.
; symbol FHT8V_HC2 ; House code 2, constant or (byte) register.
; #define FHT8V_ADR_USED (optional) ; If true then FHT8V_ADR used, else assumed 0 (multicast).
; symbol FHT8V_ADR (optional) ; Sub-address, constant or (byte) register.
; symbol FHT8V_CMD ; Constant or (usually) command byte register.
; symbol FHT8V_EXT ; Constant or (usually) command extension byte register.
; panic: ; Label for any routine to jump to to abort system operation as safely as possible.
; symbol FHT8V_RFM22_Reg_Values ; start address in EEPROM for register setup values.
; #define DEBUG (optional) ; enables extra checking, eg during unit tests.
; #define USE_MODULE_RFM22RADIOSIMPLE (optional) ; to include some specific RFM22 support.





#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use content if explicitly requested.
#define USE_MODULE_FHT8VSIMPLE_REG ; Enable placement of register settings in EEPROM.
#endif
#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use content if explicitly requested.
#define USE_MODULE_FHT8VSIMPLE_REG ; Enable placement of register settings in EEPROM.
#endif


#ifdef USE_MODULE_FHT8VSIMPLE_REG
; Register setup for FHT8V TX over RFM22B radio.
; Setup data for the RFM22 and FHT8V.
; Consists of a sequence of (reg#,value) pairs terminated with a $ff register number.  The reg#s are <128, ie top bit clear.
; Magic numbers c/o Mike Stirling!
EEPROM FHT8V_RFM22_Reg_Values, ($8,0) ; RFM22REG_OP_CTRL2: ANTDIVxxx, RXMPK, AUTOTX, ENLDM
#ifndef RFM22_IS_ACTUALLY_RFM23
; For RFM22 with RXANT tied to GPIO0, and TXANT tied to GPIO1...
EEPROM ($b,$15, $c,$12) ; DISABLE FOR RFM23
#endif
; Probably only the first of these is vital.
; 0x30 = 0x00 - turn off packet handling
; 0x32 = 0x00 - turn off address checking (rx)
; 0x33 = 0x0a - turn off header, set fixed packet length (both n/a with packet handling off), set 2 byte sync
; 0x35 = 0x20 - set preamble threshold (rx)
; 0x36-0x39 = 0x2dd4 - set sync word (this is the default anyway)
EEPROM ($30,0, $32,0, $33,$a, $36,$2d, $37,$d4, $38,0, $39,0, $35,$20)
EEPROM ($6d,$f) ; RFM22REG_TX_POWER: Somewhat above minimum TX power.
;EEPROM ($6d,8) ; RFM22REG_TX_POWER: Minimum TX power (-1dBm).
EEPROM ($6e,40, $6f,245); 5000bps, ie 200us/bit for FHT (6 for 1, 4 for 0).  10485 split across the registers, MSB first.
EEPROM ($70,$20) ; MOD CTRL 1: low bit rate (<30kbps), no Manchester encoding, no whitening.
EEPROM ($71,$21) ; MOD CTRL 2: OOK modulation.
EEPROM ($72,8) ; Deviation 5 kHz GFSK.
EEPROM ($73,0, $74,0) ; Frequency offset
; Channel 0 frequency = 868 MHz, 10 kHz channel steps, high band.
EEPROM ($75,$73, $76,100, $77,0) ; BAND_SELECT,FB(hz), CARRIER_FREQ0&CARRIER_FREQ1,FC(hz) where hz=868MHz
EEPROM ($79,35) ; 868.35 MHz - FHT
EEPROM ($7a,1) ; One 10kHz channel step.
#ifdef USE_MODULE_FHT8VSIMPLE_RX ; RX-specific settings, again c/o Mike S.
EEPROM ($1c,0xc1, $1d,0x40, $1e,0x0a, $1f,0x03, $20,0x96, $21,0x00, $22,0xda, $23,0x74, $23,0x00, $25,0xdc)
EEPROM ($2a,0x24)
EEPROM ($2c,0x28, $2d,0xfa, $2e,0x29)
#endif
; Terminate the initialisation data.
EEPROM ($ff,$ff)
#rem ; Sample control register dump (from RFM23B) by Mike S 20130221 including RX values, for reference:
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 CC CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0F 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37
#endrem
#endif



#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use TX support content if explicitly requested.
#undefine USE_MODULE_FHT8VSIMPLE_TX ; Prevent duplicate use...


#ifdef USE_MODULE_RFM22RADIOSIMPLE ; RFM22 module must be loaded to use this.
; Create and be ready to send via RFM22TXFIFO the command from the FHT_XXX values.
; The frame sent we be prefixed by a RFM22B-receiver-friendly 0xaaaaaaaa pre-preamble.
; Uses the ScratchMemBlock.
; B0, tempB0, tempB1 are destroyed.
; This routine can be run at any clock speed.
FHT8VCommandQueueTXViaRFM22:
    ; Create an FHT8V byte stream in ScratchMemBlock suitable to TX via RFM22, low byte first, msbit of each byte first.
    gosub FHT8VCreate200usBitStream

    ; Load bit stream (and preambles) into RFM22 using burst-write mode...
    low RFM22_nSEL_O
    B0 = $ff ; TX FIFO (burst) write to register $7f.
    gosub SPI_shiftout_byte_MSB_preclB0
    ; RFM22B-friendly pre-preamble of 4 x 0xAA.
    B0 = $aa
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclB0
    ; Send out FHT8V encoded frame.
    tempB0 = ScratchMemBlock
    do
        peek tempB0, B0
        if B0 = $ff then exit
        gosub SPI_shiftout_byte_MSB_preclB0
        inc tempB0
    loop
    high RFM22_nSEL_O
    return
#endif


; Create stream of bytes to be transmitted to FHT80V at 200us per bit, msbit of each byte first.
; Stream of bytes is written to memory starting at ScratchMemBlock (and may not extend beyond ScratchMemBlockEnd).
;
; Byte stream is terminated by $ff byte which is not a possible valid encoding.
; On entry, FHT8V_HC1, FHT8V_HC2, FHT8V_ADR (0 if undefined), FHT8V_CMD and FHT8V_EXT are inputs (and not destroyed if registers).
; On exit, the memory block starting at ScratchMemBlock contains the low-byte, msbit-first bit, $ff terminated TX sequence.
; B0, tempB0, tempB1 are destroyed.
FHT8VCreate200usBitStream:
    ; Generate preamble.
    poke ScratchMemBlock, $cc, $cc, $cc, $cc, $cc, $cc ; First 12x 0 bits of preamble, encoded.
    tempB0 = ScratchMemBlock + 6
    poke tempB0, $ff ; Initialise for _FHT8VCreate200usAppendEncBit routine.

    ; Push remaining 1 of preamble.
    Bit7 = 1
    gosub _FHT8VCreate200usAppendEncBit
;sertxd("H");

    ; Generate body.
    B0 = FHT8V_HC1
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_HC2
    gosub _FHT8VCreate200usAppendByteEP
#ifdef FHT8V_ADR_USED
    B0 = FHT8V_ADR
#else
    B0 = 0 ; Default/broadcast.  TODO: could possibly be further optimised to send 0 value more efficiently.
#endif
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_CMD
    gosub _FHT8VCreate200usAppendByteEP
    B0 = FHT8V_EXT
    gosub _FHT8VCreate200usAppendByteEP
    ; Generate checksum.
#ifdef FHT8V_ADR_USED
    B0 = $c + FHT8V_HC1 + FHT8V_HC2 + FHT_ADR + FHT8V_CMD + FHT8V_EXT
#else
    B0 = $c + FHT8V_HC1 + FHT8V_HC2 + FHT8V_CMD + FHT8V_EXT
#endif
    gosub _FHT8VCreate200usAppendByteEP

    ; Generate trailer.
;sertxd("T");
    ; Append 0 bit for trailer.
    Bit7 = 0
    gosub _FHT8VCreate200usAppendEncBit
    ; Append extra 0 bit to ensure that final required bits are flushed out.
    ;Bit7 = 0
    gosub _FHT8VCreate200usAppendEncBit

#ifdef DEBUG ; Extra check
    if tempB0 > ScratchMemBlockEnd then panic
    if tempB0 < ScratchMemBlock then panic ; Wrapped round?
#endif
    poke tempB0, $ff ; Terminate TX bytes.
;sertxd(13,10);
    return

; Appends encoded 200us-bit representation of logical msbit from B0.
; If the most significant bit of B0 (Bit7) is 0 this appends 1100 else this appends 111000
; msb-first to the byte stream being created by FHT8VCreate200usBitStream.
; Does NOT destroy B0.
; tempB0 must be pointing at the current byte to update on entry which must start off as $ff;
; this will write the byte and increment tempB0 (and write $ff to the new location) if one is filled up.
; Partial byte can only have even number of bits present, ie be in one of 4 states.
; Two least significant bits used to indicate how many bit pairs are still to be filled,
; so initial $ff value (which is never a valid complete filled byte) indicates 'empty'.
; Destroys tempB1.
_FHT8VCreate200usAppendEncBit:
;sertxd(#bit7);
    peek tempB0, tempB1
    tempB1 = tempB1 & 3 ; Find out how many bit pairs are left to fill in the current byte.
    if bit7 = 0 then ; Appending 1100
        select tempB1
            case 3 ; Empty target byte (should be $ff currently).
                poke tempB0, %11001101 ; Write back partial byte (msbits now 1100 and two bit pairs remain free).
            case 2 ; Top bit pair already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11000000 ; Preserve existing ms bit-pair.
                tempB1 = tempB1 |   %110000 ; (middle four bits 1100 and one bit pair remains free)
                poke tempB0, tempB1; Write back partial byte.
            case 1 ; Top two bit pairs already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11110000 ; Preserve existing ms bit-pairs.
                tempB1 = tempB1 |     %1100 ; (bottom four bits 1100)
                poke tempB0, tempB1 ; Write back full byte.
                inc tempB0 ; Move to next byte
                poke tempB0, $ff ; Initialise next byte for incremental update.
            else ; Top three bit pairs already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11111100 ; Preserve existing ms bit-pairs.
                tempB1 = tempB1 |       %11 ; (OR in leading 11 bits)
                poke tempB0, tempB1 ; Write back full byte.
                inc tempB0 ; Move to next byte
                poke tempB0, %00111110 ; Write trailing 00 bits and indicate 3 bit-pairs free for incremental update.
        endselect
    else ; Appending 111000
        select tempB1
            case 3 ; Empty target byte (should be $ff currently).
                poke tempB0, %11100000 ; (one bit pair remains free)
            case 2 ; Top bit pair already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11000000 ; Preserve existing ms bit-pair.
                tempB1 = tempB1 |   %111000 ; Fill lsbits with 111000.
                poke tempB0, tempB1 ; Write back full byte.
                inc tempB0 ; Move to next byte
                poke tempB0, $ff ; Initialise next byte for incremental update.
            case 1 ; Top two bit pairs already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11110000 ; Preserve existing ms bit-pairs.
                tempB1 = tempB1 |     %1110 ; (bottom four bits 1110)
                poke tempB0, tempB1 ; Write back full byte.
                inc tempB0 ; Move to next byte
                poke tempB0, %00111110 ; Write trailing 00 bits and indicate 3 bit-pairs free for incremental update.
            else ; Top three bit pairs already filled.
                peek tempB0, tempB1
                tempB1 = tempB1 & %11111100 ; Preserve existing ms bit-pairs.
                tempB1 = tempB1 |       %11 ; (OR in leading 11 bits)
                poke tempB0, tempB1 ; Write back full byte.
                inc tempB0 ; Move to next byte
                poke tempB0, %10001101 ; Write trailing 1000 bits and indicate 2 bit-pairs free for incremental update.
        endselect
    endif
    return

; Appends byte in B0 msbit first plus trailing even parity bit (9 bits total)
; to the byte stream being created by FHT8VCreate200usBitStream.
; Destroys B0.
_FHT8VCreate200usAppendByteEP:
;sertxd("-");
    ; Send the byte msbit first while building the parity bit in bit 0.
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 7.
    if bit7 = 0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 6.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 5.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 4.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 3.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 2.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 1.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    gosub _FHT8VCreate200usAppendEncBit ; Original bit 0.
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    bit7 = bit0 ; Computed parity is in bit 0...
    gosub _FHT8VCreate200usAppendEncBit ; Even parity bit.
    return

#endif USE_MODULE_FHT8VSIMPLE_TX




#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use RX support content if explicitly requested.
#undefine USE_MODULE_FHT8VSIMPLE_RX ; Prevent duplicate use...



#endif
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

; TODO: ADD HYSTERESIS

; RECENT CHANGES
; DHD20130221: Bumped threshold up a little to 33 (~13%) based on observations.


; Dependencies:
; INPUT_LDR ADC input pin symbol must be defined with LDR to +V and pull-down to 0V (so more light gives higher value).
; isRoomInUse bit symbol must be defined; will be set to 1 if room is light enough for occupancy/activity, 0 otherwise.
; tempB0 temporary byte symbol must be defined; will be used/overwritten.

; Using techsupplies.co.uk SEN002 (like GL5528 1M+ dark, ~10k @ 10 Lux) with fixed pull-down resistor.
; Works OK with 10k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (5V) at threshold of 25 (~10% max).
; Works OK with 100k pull-down and http://www.techsupplies.co.uk/SEN002 LDR to +V (3.3V) at threshold of 25 (~10% max).  ("Dark" at night ~5.)



#ifdef USE_MODULE_LDROCCUPANCYDETECTION ; Only use content if explicitly requested.
#undefine USE_MODULE_LDROCCUPANCYDETECTION ; Prevent duplicate use...



    
; Attempts to detect room use/occupancy from ambient light levels: sets isRoomInUse if probably in use.    
getRoomInUseFromLDR:
	; Check occupancy, setting isRoomInUse 1 if activity else 0.
    ; Use ambient light level to help guess occupancy; very dark (<13% of max) implies no active occupants.
    readadc INPUT_LDR, tempB0
    if tempB0 < 33 then
        isRoomInUse = 0
    else
        isRoomInUse = 1
    end if
    return





#endif
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

; ****** RFM22B-radio-simple.inc.bas ****** in module library
; Basic support for RFM22B (or RFM23B) radio transceivers in SPI mode (si443x chipset), and no use of interrupts.
; Appendable PICAXE basic fragment.

; Many thanks to Mike Stirling http://mikestirling.co.uk/2012/10/hacking-wireless-radiator-valves-with-gnuradio/
; for register settings, the 200us encoding, and lots of hand-holding!

; RECENT CHANGES:
; DHD20130222: Using pause and loop limit in RFM22TXFIFO to avoid lockup in that routine (bashing on SPI too hard)?
; DHD20130222: Using RFM22ModeStandbyAndClearState at end of init and TXFIFO routines in hope of reducing power consumption (turning interrupts off).


; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol RFM22_nSEL_O ; output bit, low to select/enable RFM22.
; #define RFM22_nIRQ_I (optional) ; input bit, low to indicate interrupt from RFM22: without this software polling will be used.
; #define symbol RFM22_nIRQ_I_PIN (optional) ; inputX version of RFM22_nIRL_I.  Must be defined iff RFM22_nIRQ_I is.
; #define KEEP_ELAPSED_TIME_ACCURATE (optional) ; avoid nap/sleep etc if defined, and use pause instead.

; For receive:
; symbol ScratchMemBlock ; Start of contiguous scratch memory area (to RX FIFO data into) < 0x100.
; symbol ScratchMemBlockEnd ; Inclusive end of scratch memory area, > ScratchMemBlock and < 0x100.




#ifdef USE_MODULE_RFM22RADIOSIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_RFM22RADIOSIMPLE ; Prevent duplicate use...

; See Hope RF RFM22/RFM23 data sheet for register and value definitions.
symbol RFM22REG_INT_STATUS1 = $03 ; Interrupt status register 1.
symbol RFM22REG_INT_STATUS2 = $04 ; Interrupt status register 2.
symbol RFM22REG_INT_ENABLE1 = $05 ; Interrupt enable register 1.
symbol RFM22REG_INT_ENABLE2 = $06 ; Interrupt enable register 2.
symbol RFM22REG_OP_CTRL1 = $07 ; Operation and control register 1.
symbol RFM22REG_OP_CTRL1_SWRES = $80 ; Software reset (at write) in OP_CTRL1.
symbol RFM22REG_OP_CTRL2 = $08 ; Operation and control register 2.
symbol RFM22REG_TX_POWER = $6d ; Transmit power.
symbol RFM22REG_FIFO = $7f ; Transmit FIFO on write.
; Allow validation of RFM22/FRM23 device and SPI connection to it.
symbol RFM22_SUPPORTED_DEVICE_TYPE = 0x08 ; Read from register 0.
symbol RFM22_SUPPORTED_DEVICE_VERSION = 0x06 ; Read from register 1.


; Minimal set-up of I/O (etc) after system power-up.
; Perform a software reset and leave the radio deselected and in a low-power and safe state.
; Destroys some or all of tempB0, tempB1, tempB2, B0 and SPI_DATAB.
RFM22PowerOnInit:
    ; Make sure nSEL set as output and RFM22 deselected ASAP.
    high RFM22_nSEL_O
    ; Warm up SPI.
    gosub SPI_init
    ; Software reset.
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = RFM22REG_OP_CTRL1_SWRES
    gosub RFM22WriteReg8Bit
    ; TODO : wait for nIRQ to fall if pin defined.
    ; Drop into minimal-power standby mode with interrupts off, etc.
    ;gosub RFM22ModeStandbyAndClearState
    gosub RFM22ModeStandby
    return

; Simple test that RFM22 seems to be correctly connected over SPI.
; Returns 0 in SPI_DATAB if RFM22 appears present and correct, else non-zero value for something wrong.
; Can be called before or after RFM22PowerOnInit.
RFM22CheckConnected:
    SPI_DATAB = 0 ; device type
    gosub RFM22ReadReg8Bit
    if SPI_DATAB != RFM22_SUPPORTED_DEVICE_TYPE then RFM22CheckConnectedError
    SPI_DATAB = 1 ; device version
    gosub RFM22ReadReg8Bit
    if SPI_DATAB != RFM22_SUPPORTED_DEVICE_VERSION then RFM22CheckConnectedError
    SPI_DATAB = 0 ; All OK.
    return
; Error return.
RFM22CheckConnectedError:
    SPI_DATAB = 1 ; Error value
    return

; Set up a block of RFM22 registers from EEPROM (for efficiency/clarity).
; Pass the starting address in EEPROM as tempB0.
; EEPROM data is a sequence of (reg#,value) pairs terminated with a $ff register.  The reg#s are <128, ie top bit clear.
; Destroys tempB0, tempB2, SPI_DATAB
RFM22RegisterBlockSetup:
    do
        read tempB0, SPI_DATAB, tempB2
        if SPI_DATAB > 127 then exit
        gosub RFM22WriteReg8Bit ; Must not destroy tempB0.
        tempB0 = tempB0 + 2
    loop
    return

#rem
; Read status and clear interrupts.
; Status (from status register 1) is returned in SPI_DATAB: 0 indicates no pending interrupts.
; DOES NOT READ/CLEAR STATUS REGISTER 2.
; Destroys B0 and tempB0.
RFM22ReadStatus1:
    SPI_DATAB = RFM22REG_INT_STATUS1
    low RFM22_nSEL_O
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    high RFM22_nSEL_O
    return
#endrem

; Read status (both registers) and clear interrupts.
; Status register 1 is returned in tempB2: 0 indicates no pending interrupts.
; Status register 2 is returned in SPI_DATAB: 0 indicates no pending interrupts.
; Destroys SPI_DATAB, B0 and tempB0.
RFM22ReadStatusBoth:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    tempB2 = SPI_DATAB
    gosub SPI_shiftin_byte_MSB_preclock
    high RFM22_nSEL_O
    return

; Read/discard status (both registers) to clear interrupts.
; Destroys SPI_DATAB, B0 and tempB0.
RFM22ClearInterrupts:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    ;gosub SPI_shiftin_byte_MSB_preclock
    ;gosub SPI_shiftin_byte_MSB_preclock
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    return


; Enter standby mode and clear FIFOs, status, etc.
; May be necessary to achieve lowest power consumption.
; Destroys SPI_DATAB, tempB2, B0.
; FIXME: far too slow
RFM22ModeStandbyAndClearState:
    ; Go into standby mode (inlined RFM22ModeStandby subroutine).
    SPI_DATAB = RFM22REG_OP_CTRL1
    gosub RFM22WriteReg8Bit0
    ; Clear RX and TX FIFOs.
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 3 ; FFCLRRX | FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0
    ; Clear any pending interrupts.  FIXME: may need to be done after disabling ints to avoid races?
    gosub RFM22ClearInterrupts
    ; Disable all interrupts.  (May help radio power down fully.)
    SPI_DATAB = RFM22REG_INT_ENABLE1
    gosub RFM22WriteReg8Bit0
    SPI_DATAB = RFM22REG_INT_ENABLE2
    gosub RFM22WriteReg8Bit0
    return

; Clear RX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearRXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 2 ; FFCLRRX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0
    return

; Clear RX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearTXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 1 ; FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0
    return

; Enter standby mode (consume least possible power but retain register contents).
; Destroys SPI_DATAB, B0.
RFM22ModeStandby:
    SPI_DATAB = RFM22REG_OP_CTRL1
    gosub RFM22WriteReg8Bit0
    return

; Enter 'tune' mode (to enable fast transition to TX or RX mode).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTune:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000011 ; PLLON | XTON
    gosub RFM22WriteReg8Bit
    return

; Enter transmit mode (and send any packet queued up in the TX FIFO).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00001001 ; TXON | XTON
    gosub RFM22WriteReg8Bit
    return

; Enter receive mode.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeRX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000101 ; RXON | XTON
    gosub RFM22WriteReg8Bit
    return

; Append a single byte to the transmit FIFO.
; Does not check for or prevent overflow.
; Byte to write should be in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteByteToTXFIFO:
    SPI_DATAB = RFM22REG_FIFO
    gosub RFM22WriteReg8Bit
    return

; Transmit contents of on-chip TX FIFO then go back to low-power standby mode.
; Destroys tempB0, tempB1, tempB2, B0, SPI_DATAB.
; Note: Needs early move to 'tune' mode to work other than with default (4MHz) clock or 8MHz.
; FIXME: still unreliable if > 8MHz from about "gosub RFM22ModeTX" onwards.
RFM22TXFIFO:
    gosub RFM22ModeTune ; Warm up the PLL for quick transition to TX below.
    ; Enable interrupt on packet send.
    SPI_DATAB = RFM22REG_INT_ENABLE1
    tempB2 = 4
    gosub RFM22WriteReg8Bit
    ; Explicitly disable everything else with 0 write to INT_ENABLE_2 too.
    SPI_DATAB = RFM22REG_INT_ENABLE2
    gosub RFM22WriteReg8Bit0
    gosub RFM22ClearInterrupts ; Clear any current status...
    gosub RFM22ModeTX ; Enable TX mode and transmit TX FIFO contents.

; FIXME: setfreq m8 ; NEEDED HERE TO BE RELIABLE

    ; Whole TX likely to take > 60ms for a typical message; avoid bashing SPI too hard!
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    for tempB1 = 0 to 32 ; Should be plenty of time even at max clock rate...
        pause 18 ; May be a fraction of nominal pause time if running at high clock speed.
#else
    for tempB1 = 0 to 8 ; Should be plenty of time even with some wobble on nap timer...
        nap 0 ; Save a little energy...
#endif
        gosub RFM22ReadStatusBoth
        if tempB2 != 0 then exit ; Packet sent...
    next tempB1 ; Spin until packet sent...  COULD POLL INPUT PIN FROM nIRQ FIRST/INSTEAD.
    ; TODO: possible retransmit after few (randomised?) ms gap for improved reliability?
    gosub RFM22ModeStandbyAndClearState ; Back to low-power standby mode.
    return

#rem
; Receive in FIFO mode to scratch memory area ScratchMemBlock.
; Maximum length of message that can be received is limited to the scratch area size.
RFM22RXFIFO:
    gosub RFM22ModeStandbyAndClearState ; Known state, FIFOs cleared, standby mode.

    ; Enable sync-detect interrupt

    ; TODO

    return
#endrem


; Reads a byte from a radio register over SPI.
; Register number in SPI_DATAB on call (with msb / bit 7 = 0 for read).
; Result is returned in SPI_DATAB.
; Destroys tempB0, B0.
RFM22ReadReg8Bit:
    low RFM22_nSEL_O
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclock
    high RFM22_nSEL_O
    return

; Writes a byte to a radio register over SPI.
; Register number in SPI_DATAB on call (will be destroyed); $80 is ORed in to enforce write mode.
; Data content to write in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit:
    low RFM22_nSEL_O
    B0 = SPI_DATAB | $80
    gosub SPI_shiftout_byte_MSB_preclB0
    B0 = tempB2
    gosub SPI_shiftout_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a zero byte to a radio register over SPI.  (Optimised common case.)
; Register number in SPI_DATAB on call (will be destroyed); $80 is ORed in to enforce write mode.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit0:
    low RFM22_nSEL_O
    B0 = SPI_DATAB | $80
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    return








#endif
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

; ****** SPISimple.inc.bas ****** in module library
; Basic support for SPI I/O.
; Appendable PICAXE basic fragment.



; Dependencies:
; Must already be declared
;symbol SPI_SCLK_O (pin)         ; SPI clock (output)
;symbol SPI_SDI (pin)            ; SPI data (input) to device SDO (may need weak h/w pull-up)
;symbol SPI_SDI_PIN (inpin)      ; SPI data (input) in inputX format
;symbol SPI_SDO (pin)            ; SPI data (output) to device SDI
;symbol SPI_SDO_PIN (outpin)     ; SPI data (output) in outpinX.Y format: ***must be set to output!***
;symbol SPI_DATAB (byte)         ; SPI write byte from here and read byte to here
;symbol tempB0 (byte)            ; temp working variable
;symbol tempB1 (byte)            ; temp working variable


#ifdef USE_MODULE_SPISIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_SPISIMPLE ; Prevent duplicate use...


; Units to 'pulseout' SPI_SCLK_O ; 10us units at normal clock but less at higher clock speeds
; Less than 10us seems unreliable, so use something >= 4 to allow for 4x--8x normal clock speed.
symbol SPI_PULSEOUT_UNITS = 8 ; 10us at 8x clock, 20us at 4x clock, 80us at normal clock.


; SPI initialisation.
; Mainly makes sure that inputs and outputs are pointing in the right direction.
SPI_init:
    output SPI_SCLK_O, SPI_SDO
    input SPI_SDI
    return


; SPI shift in (ie read) a single byte, most-significant bit first, data pre-clock.
; Returns input data in SPI_DATAB byte variable.
; Destroys tempB0.
SPI_shiftin_byte_MSB_preclock:
    SPI_DATAB = 0
    for tempB0 = 0 to 7
        SPI_DATAB = SPI_DATAB + SPI_DATAB    ; shift left as MSB first
        if SPI_SDI_PIN != 0 then
            SPI_DATAB = SPI_DATAB + 1       ; set LSB if SDI (incoming bit) == 1
        end if
        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS    
    next tempB0
    return

; SPI shift in (ie read) a single byte, most-significant bit first, data post-clock.
; Returns input data in SPI_DATAB byte variable.
; Destroys tempB0.
SPI_shiftin_byte_MSB_postclock:
    SPI_DATAB = 0
    for tempB0 = 0 to 7
        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS    
        SPI_DATAB = SPI_DATAB + SPI_DATAB    ; shift left as MSB first
        if SPI_SDI_PIN != 0 then
            SPI_DATAB = SPI_DATAB + 1       ; set LSB if SDI (incoming bit) == 1
        end if
    next tempB0
    return

#rem
; SPI shift out (ie write) a single byte, most-significant bit first, data pre-clock.
; Sends output data from SPI_DATAB byte variable.
; Destroys tempB0, tempB1, SPI_DATAB.
;SPI_shiftout_byte_MSB_preclock:
;    for tempB0 = 0 to 7
;        tempB1 = SPI_DATAB & $80
;        if tempB1 = 0 then
;            low SPI_SDO
;        else
;            high SPI_SDO
;        end if
;        pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
;        SPI_DATAB = SPI_DATAB + SPI_DATAB
;    next tempB0
;    return
#endrem

; SPI shift out (ie write) a single byte, most-significant bit first, data pre-clock.
; Sends output data from SPI_DATAB byte variable.
; Destroys B0 only.
; Unrolled for speed and to reduce the working memory required: a few bytes larger than loop version...
;
; SPI_SDO_PIN must be an 'output' and set to output, see: http://www.picaxeforum.co.uk/showthread.php?23186-Bit-banging-head-banging
SPI_shiftout_byte_MSB_preclock:
    B0 = SPI_DATAB
SPI_shiftout_byte_MSB_preclB0: ; As for SPI_shiftout_byte_MSB_preclock but sends B0 rather than SPI_DATAB and does not destroy B0 (nor SPI_DATAB).
    SPI_SDO_PIN = bit7
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit6
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit5
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit4
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit3
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit2
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit1
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    SPI_SDO_PIN = bit0
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return

; SPI shift out (ie write) a single zero byte, most-significant bit first, data pre-clock.
; This is as fast as is reasonably possible, with unrolled code, etc.
SPI_shiftout_0byte_MSB_pre:
    low SPI_SDO
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return


#endif
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

; ****** X10TXSimple.inc.bas ****** in module library
; Simple software-timed / bit-banging X10 RF transmit.
; Appendable PICAXE basic fragment.



; Dependencies:
; X10WordOut word symbol must be defined.

#ifdef USE_MODULE_X10TXSIMPLE ; Only use content if explicitly requested.
#undefine USE_MODULE_X10TXSIMPLE ; Prevent duplicate use...


; Sends X10WordOut; content of work may be destroyed.
; Based on J C Burchell version 1.0 2009 code at https://docs.google.com/document/pub?id=1dF5rpRkv-Ty3WcXs8D9Oze86hR50ZI96RzNrMvd_S0U
; Runs overspeed to meet timing constraints.
X10Send:

	; TODO

    return




#endif
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

; ****** empty.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; Does nothing, takes no space, has no dependencies.

#ifdef USE_MODULE_EMPTY ; Only use content if explicitly requested.
#undefine USE_MODULE_EMPTY ; Prevent duplicate use...
    ; Nothing to see here, move along please...
#endif
