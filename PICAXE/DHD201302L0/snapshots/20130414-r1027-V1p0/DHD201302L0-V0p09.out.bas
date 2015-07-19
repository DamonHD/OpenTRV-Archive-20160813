
; GENERATED/OUTPUT FILE: DO NOT EDIT!
; Built 2013/14/04 11:12.
; GENERIC NODE BUILD.
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

; TRV (and boiler-node) global configuration parameters for V0.09 PCB1 hardware.
; Should contain one #picaxe and one #define CONFIG_... and nothing else (uncommented).


; 18M2+ for V0.09 PCB1 (or earlier).
#picaxe 18M2


; Define/uncomment exactly one of the CONFIG_XXX labels to enable a configuration set below.
; Some can be specific to particular locations and boards,
; others can be vanilla ready to be configured by the end-user one way or another.

;#define CONFIG_GENERIC_ROOM_NODE
;#define CONFIG_GENERIC_BOILER_NODE
;#define CONFIG_GENERIC_RANDB_NODE
;#define CONFIG_GENERIC_DHW_NODE


; Some specific/example configs.
#define CONFIG_DHD_STUDY
;#define CONFIG_DHD_KITCHEN
;#define CONFIG_DHD_LIVINGROOM
;#define CONFIG_DHD_BEDROOM1
;#define CONFIG_DHD_TESTLAB
;#define CONFIG_BH_DHW ; Bo's hot water.

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
symbol SPI_SDO_PIN = outpinB.3     ; SPI data (output) in pinX.Y format.
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

; TRV (and boiler-node) body including control loop for DHD201203 level-0 spec on V0.09 PCB1 hardware.

; A #picaxe and #define CONFIG_... should have been defined textually above this in the .bas file,
; and the I/O pin definitions and any preliminary 'safe' initialisation also.

; See end for TODO and RECENT CHANGES.

#no_end ; Main loop is non-terminating, so save a few bytes!



;-----------------------------------------
; UI DESCRIPTION
; Button causes cycling through 'off'/'frost' target of 5C, 'warm' target of ~18C,
; and an optional 'bake' mode that raises the target temperature to up to ~24C
; for up to ~30 minutes or until the target is hit then reverts to 'warm' automatically.
; (Button may have to be held down for up to a few seconds to get the unit's attention.)
; Acknowledgement is medium/long/double flash in new mode
; (medium is frost, long is 'warm', long+medium is 'bake').

; Without the button pressed,
; the unit generates one to three short flashes on a two-second cycle if in heat mode.
; A first flash indicates "warm mode".  (This first flash will be lengthened if a schedule is set.) 
; A second flash if present indicates "calling for heat".
; A third flash if present indicates "bake mode" (which is automatically cancelled after a short time, or if the high target is hit).

; This may optionally support an interactive CLI over the serial connection,
; with reprogramming initiation permitted (instead of CLI) while the UI button is held down.

; If target is not being met then aim to turn TRV on/up and call for heat from the boiler too,
; else if target is being met then turn TRV off/down and stop calling for heat from the boiler.
; Has a small amount of hysteresis to reduce short-cycling of the boiler.
; Does some proportional TRV control as target temperature is neared to reduce overshoot.

; This can use a simple setback (drops the 'warm' target a little to save energy)
; eg using an LDR, ie reasonable ambient light, as a proxy for occupancy.



;-----------------------------------------
; PRE-DEFINED CONFIG_... IMPLEMENTATION/EXPANSION

#ifdef CONFIG_DHD_STUDY ; DHD's study with TRV.
; IF DEFINED: this unit supports CLI over the USB/serial connection, eg for run-time reconfig.
;#define SUPPORT_CLI
; IF DEFINED: this unit supports BAKE mode.
#define SUPPORT_BAKE
; IF DEFINED: this unit may run on 2xAA cells, preferably rechargeable eg NiMH, ~2V--2.4V, and should monitor supply voltage with calibadc.
;#define SUPPLY_VOLTAGE_LOW_2AA ; May require limiting clock speed and using some alternative peripherals/sensors...
; IF DEFINED: this unit will act as boiler-control hub listening to remote thermostats, possibly in addition to controlling a local TRV.
;#define BOILER_HUB
; IF DEFINED: this unit will act as a thermostat controlling a local TRV (and calling for heat from the boiler).
#define LOCAL_TRV
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.
; IF DEFINED: RFM23 is in use in place of RFM22.
#define RFM22_IS_ACTUALLY_RFM23 ; RFM23 used on V0.09 PCB1.
; IF DEFINED: good RF environment means that TX power level can be reduced.
#define RFM22_GOOD_RF_ENV ; Good ground-plane and antenna: drop TX level.
; IF DEFINED: use simple LDR-based detection of room use/occupancy; brings in getRoomInUseFromLDR subroutine.
#define USE_MODULE_LDROCCUPANCYDETECTION
; If LDR is not to be used then specifically define OMIT_... as below.
;#define OMIT_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
; IF DEFINED: use DS1306 RTC for accurate elapsed time measures at least.
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: use MCP79410 RTC (with I2C).
;#define USE_MODULE_MCP79410_RTC_SIMPLE
; IF DEFINED: produce regular status reports on sertxd.
;#define SERTXD_STATUS_REPORTS
; IF DEFINED: use active-low LEARN button.  Needs SUPPORT_SINGLETON_SCHEDULE.
;#define LEARN_BUTTON_AVAILABLE ; OPTIONAL ON V0.09 PCB1
;symbol BUTTON_LEARN_L = input5 ; C.5 ; Low when "LEARN" button pressed.
; IF DEFINED: support one on and one off time per day (possibly in conjunction with 'learn' button).
; Test simple schedule to warm in evening from 9pm to 10pm.
;#define SUPPORT_SINGLETON_SCHEDULE
;symbol DEFAULT_SINGLETON_SCHEDULE_ON = $ff ; No default on.
;symbol DEFAULT_SINGLETON_SCHEDULE_OFF = $ff ; No default off.
#endif

#ifdef CONFIG_DHD_KITCHEN ; DHD's kitchen with TRV, which also contains the boiler.
;#define SUPPORT_CLI
#define SUPPORT_BAKE
#define BOILER_HUB
#define LOCAL_TRV
symbol FHT8V_HC1 = 45 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 26 ; House code 2, constant or (byte) register.
#define USE_MODULE_LDROCCUPANCYDETECTION
#define USE_MODULE_DS1306RTCSPISIMPLE
#endif

#ifdef CONFIG_DHD_LIVINGROOM ; DHD's living room with TRV.
;#define SUPPORT_CLI
#define SUPPORT_BAKE
#define LOCAL_TRV
symbol FHT8V_HC1 = 10 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 69 ; House code 2, constant or (byte) register.
#define USE_MODULE_LDROCCUPANCYDETECTION
#define LDR_EXTRA_SENSITIVE ; LDR not exposed to much light.
#define USE_MODULE_DS1306RTCSPISIMPLE
#endif

#ifdef CONFIG_DHD_BEDROOM1 ; DHD's bedroom 1.
#define REDUCE_CODE_SPACE ; Trade off some speed for code space.
#define RFM22_IS_ACTUALLY_RFM23 ; RFM23 used on V0.09 PCB1.
#define RFM22_GOOD_RF_ENV ; Good ground-plane and antenna: drop TX level.
;#define SUPPORT_CLI
;#define SUPPORT_BAKE
#define LOCAL_TRV
symbol FHT8V_HC1 = 48 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 21 ; House code 2, constant or (byte) register.
#define USE_MODULE_LDROCCUPANCYDETECTION
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: produce regular status reports on sertxd.
#define SERTXD_STATUS_REPORTS
; IF DEFINED: use active-low LEARN button.  Needs SUPPORT_SINGLETON_SCHEDULE.
#define LEARN_BUTTON_AVAILABLE ; OPTIONAL ON V0.09 PCB1
symbol BUTTON_LEARN_L = input5 ; C.5 ; Low when "LEARN" button pressed.
; IF DEFINED: support one on and one off time per day (possibly in conjunction with 'learn' button).
#define SUPPORT_SINGLETON_SCHEDULE
symbol DEFAULT_SINGLETON_SCHEDULE_ON = $ff ; No default on.
symbol DEFAULT_SINGLETON_SCHEDULE_OFF = $ff ; No default off.
#endif

#ifdef CONFIG_DHD_TESTLAB ; DHD's test lab.
#define DEBUG
#define REDUCE_CODE_SPACE ; Trade off some speed for code space.
;#define SUPPORT_CLI
;#define SUPPORT_BAKE
#define LOCAL_TRV
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.
#define USE_MODULE_LDROCCUPANCYDETECTION
;#define LDR_EXTRA_SENSITIVE ; LDR not exposed to much light.
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: use DS1306 1Hz output for more efficient sleeping.
;#define DS1306RTC_1HZ_AVAILABLE ; NOT STANDARD ON V0.09 PCB1
;symbol RTC_1HZ_PIN = input5 ; C.5 ; High in first half of cycle (or if not connected).
; IF DEFINED: produce regular status reports on sertxd.
#define SERTXD_STATUS_REPORTS
; IF DEFINED: use active-low LEARN button.  Needs SUPPORT_SINGLETON_SCHEDULE.
#define LEARN_BUTTON_AVAILABLE ; OPTIONAL ON V0.09 PCB1
symbol BUTTON_LEARN_L = input5 ; C.5 ; Low when "LEARN" button pressed.
; IF DEFINED: support one on and one off time per day (possibly in conjunction with 'learn' button).
#define SUPPORT_SINGLETON_SCHEDULE
symbol DEFAULT_SINGLETON_SCHEDULE_ON = $ff ; No default on.
symbol DEFAULT_SINGLETON_SCHEDULE_OFF = $ff ; No default off.
#endif


#ifdef CONFIG_BO_DHW
;#define SUPPORT_BAKE ; Simple heat/no-heat operation.
#define LOCAL_TRV ; Uses FHT8V to control district heated water flow.
#define DHW_TEMPERATURES ; Run with hot-water set-points.
symbol FHT8V_HC1 = 40 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 00 ; House code 2, constant or (byte) register.
;#define USE_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
#define OMIT_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: support one on and one off time per day (possibly in conjunction with 'learn' button).
#define SUPPORT_SINGLETON_SCHEDULE
symbol DEFAULT_SINGLETON_SCHEDULE_ON = 6 ; 6am on
symbol DEFAULT_SINGLETON_SCHEDULE_OFF = 20 ; 8pm off
#endif



;-----------------------------------------
; Derived config: don't edit unless you know what you are doing!

#ifdef 18M2
symbol CLOCK_SPEED_NORMAL = m4 ; 4MHz
#ifdef KEEP_ELAPSED_TIME_ACCURATE
symbol CLOCK_SPEED_MAX = m16 ; As fast as possible while maintaining elapsed 'time' word correctly on 18M2+ and works down to minimum supply voltage.
#else
; The 18M2+ is apparently derived from the PIC16F1847,
; which implies, given the graph on page 346 of the datasheet:
; http://ww1.microchip.com/downloads/en/DeviceDoc/41453B.pdf#page=346
; that if running below 2.5V the clock frequency shouldn't be above 16MHz.
#ifdef SUPPLY_VOLTAGE_LOW_2AA
symbol CLOCK_SPEED_MAX = m16 ; As fast as possible while maintaining elapsed 'time' word correctly on 18M2+ and works down to minimum supply voltage.
#else
symbol CLOCK_SPEED_MAX = m32 ; As fast as possible for 18M2+.  Not OK at below 2.5V and thus no good for 2xAA NiMH supply.
#endif
#endif
#endif

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

; IF DEFINED: only use RFM22 RX sync to indicate call for heat from boiler rather than reading the FHT8V frame content.
#define RFM22_SYNC_ONLY_BCFH

#ifdef LEARN_BUTTON_AVAILABLE
#define SUPPORT_SINGLETON_SCHEDULE
#endif

#ifdef SUPPORT_SINGLETON_SCHEDULE
#define USE_MODULE_BCDTOOLS
#endif




;-----------------------------------------
; MAIN GLOBAL CONSTANTS
; Default frost (minimum) temperature in degrees C.
symbol FROST = 5
#ifndef DHW_TEMPERATURES
; Default warm/comfort room (air) temperature in degrees C; strictly greater than FROST.  Targets upper end of this 1C window.
symbol WARM = 17
#else ; Default settings for DHW control.
symbol WARM = 60 ; 60C+ for DHW Legionella control.
#endif

symbol BAKE_UPLIFT = 7 ; Raise target by this many degrees in 'BAKE' mode (strictly positive).

; Initial setback degrees C (non-negative).  Note that 1C setback may result in ~8% saving in UK.
symbol SETBACK = 1
; Full setback degrees C (non-negative).  Should result in significant automatic energy savings if engaged.
symbol SETBACK_FULL = 3
; Prolonged inactivity time deemed to indicate room really unoccupied to trigger full setback (seconds, strictly positive).
symbol SETBACK_FULL_S = 3600 ; 1 hour
; Maximum 'BAKE' time, ie time to crank heating up to BAKE setting (minutes, strictly positive, <255).
symbol BAKE_MAX_M = 30



;-----------------------------------------
; GLOBAL VARIABLES
; B0, B1, B2 (aka W0 and bit0 to bit23) reserved as working registers and for bit manipulation.

; B3 as persistent global booleans
symbol globalFlags = B3 ; Global flag/boolean variables.
; Boolean flag 1/true if slow operation has been performed in main loop and no slow op should follow it.
symbol slowOpDone = bit24
; Boolean flag 1/true if in 'warm' mode (0 => 'frost' mode).
symbol isWarmMode = bit25
isWarmMode = 0 ; Start up not calling for heat.
; Boolean flag 1/true if room appears to be lit, or at least not in darkness.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
symbol isRoomLit = bit26
isRoomLit = 1 ; Start up assuming that the room is lit.
#else
symbol isRoomLit = 1 ; No LDR, so cannot tell when room is dark so assume always lit.
#endif
#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Boolean flag 1/true if synced with FHT8V, initially false.
symbol syncedWithFHT8V = bit27
; Boolean flag 1/true if target TRV should actually be open having received suitable command from this node (ie model of remote state).
symbol FHT8V_isValveOpen = bit28
#endif
;
; Boolean temporary.
symbol tempBit0 = bit31

; B4 (aka part of W2)
; Current TRV value percent open (0--100 inclusive) and boiler heat-demand level.
; Anything other than zero may be treated as 100 by boiler or TRV.
symbol TRVPercentOpen = b4 ; Should start off at zero, ie rad closed, boiler off.

; B5 (aka part of W2): delayable job priority task n pending at each level (MSB highest pri) if bit 1.
; A zero value implies no delayable jobs pending currently.
symbol jobsPending = b5
jobsPending = 0 ; No jobs pending initially...
; Code in loop body should be ordered to map priority here.
;symbol MASK_JP_FS20 = %10000000 ; FS20 TX (highest because of timing tightness)
;symbol MASK_JP_UI   = %01000000 ; UI (nearly highest for responsiveness)
symbol MASK_JP_TEMP = %00100000 ; Temperature read
symbol MASK_JP_OLDR = %00010000 ; Occupancy sensing with LDR
symbol MASK_JP_HTCL = %00001000 ; Heat call to boiler, wired and wireless; lower pri than sensors to happen only when they are done.
symbol MASK_JP_HTC2 = %00000100 ; Repeat randomised wireless heat call to boiler to help ensure not missed.
#ifdef SERTXD_STATUS_REPORTS
symbol MASK_JP_STAT = %00000010 ; Status report on sertxd.
#endif

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
#ifdef TIME_LSD_IS_BINARY
symbol TIME_CYCLE_S = 256
#else
symbol TIME_CYCLE_S = 60
#endif

; B18 & B19 (aka W9)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol FHT8V_CMD = b18 ; Command byte register (eg "set valve to given open fraction").
symbol FHT8V_EXT = b19 ; Command extension byte register (valve shut).
; W10 (aka B20 & B21)
; RESERVED FOR FHT8V_HC1 and FHT8V_HC2
#endif

; B22 & B23 (aka W11)
#ifdef BOILER_HUB
symbol boilerCountdownS = B22 ; Time in seconds before remote call for heat times out.
; Time in seconds from last remote call for heat to boiler going off.
; Each node should broadcast at least once per minute so needs to be a little over 60s minimum to allow for clock skew.
symbol BOILER_CALL_TIMEOUT_S = 62 ; Must be > 60.
#endif
; B23
#ifdef SUPPORT_BAKE
symbol bakeCountdownM = B23 ; Time remaining in 'BAKE' mode (minutes) else 0 if not in bake mode.
#endif

; B24 & B25 (aka W12)
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol syncStateFHT8V = B24 ; Sync status and down counter for FHT8V, initially zero; value not important once in sync.
; If syncedWithFHT8V = 0 then resyncing, AND
;     if syncStateFHT8V is zero then cycle is starting
;     if syncStateFHT8V in range [241,3] (inclusive) then sending sync command 12 messages.
symbol halfSecondsToNextFHT8VTX = B25 ; Nominal half seconds until next command TX.
#endif

#ifdef DEBUG
; B26
; Count of missed ticks (and sync restarts).
symbol missedTickCount = B26
#endif


; TX/RX scratchpad block...
;symbol ScratchMemBlock = 0x50 ; Start of contiguous scratch memory area available on all PICAXE via peek/poke/ptr, apparently: http://www.picaxe.com/BASIC-Commands/Variables/poke/
;symbol ScratchMemBlockEnd = 0x7e ; End of contiguous scratch memory area; > ScratchMemBlock and < $7f.

#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Contiguous area used to store FHT8V TRV outgoing command for TX: must be at least 46 bytes long (50 if 4-byte RFM22 pre-preamble being used).
symbol FHT8VTXCommandArea = 0x50
#endif



;-----------------------------------------
; EEPROM
; Some allocated spaces may not be used.

#ifdef SUPPORT_SINGLETON_SCHEDULE
symbol EEPROM_SINGLE_PROG_ON_MM = 0 ; Location in EEPROM of minutes for single-program 'on' start (0--59, not BCD).  Before HH value in EEPROM.
symbol EEPROM_SINGLE_PROG_ON_HH = 1 ; Location in EEPROM of hour for single-program 'on' start (0--23, not BCD), $ff if not used.
symbol EEPROM_SINGLE_PROG_OFF_MM = 2 ; Location in EEPROM of minutes for single-program 'off' start (0--59, not BCD).  Before HH value in EEPROM.
symbol EEPROM_SINGLE_PROG_OFF_HH = 3 ; Location in EEPROM of hour for single-program 'off' start (0--23, not BCD), $ff if not used.
EEPROM EEPROM_SINGLE_PROG_ON_MM, (0)
EEPROM EEPROM_SINGLE_PROG_ON_HH, (DEFAULT_SINGLETON_SCHEDULE_ON)
EEPROM EEPROM_SINGLE_PROG_OFF_MM, (0)
EEPROM EEPROM_SINGLE_PROG_OFF_HH, (DEFAULT_SINGLETON_SCHEDULE_OFF)
#endif

#rem
#ifdef USE_MODULE_FHT8VSIMPLE_TX
symbol EEPROM_FHT8V_HC1 = 4 ; Location in EEPROM of saved FHT8V house code 1.
symbol EEPROM_FHT8V_HC2 = 5 ; Location in EEPROM of saved FHT8V house code 2.
#endif
#endrem

#ifdef USE_MODULE_RFM22RADIOSIMPLE
symbol FHT8V_RFM22_Reg_Values = 4 ; Start address in EEPROM for RFM22B register setup values for FHT8V: seq of (reg#,value) pairs term w/ $ff reg#.
#endif



;-----------------------------------------
; INITIALISATION
; Do minimal 'safe' I/O setup ASAP.

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


; Get initial environmental readings before the main loop starts so all values are valid.
; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
gosub getTemperature
; Get ambient light level, if module present.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
gosub getRoomInUseFromLDR
#endif
; Update targets, output to TRV and boiler, etc, to be sensible before main loop starts.
gosub computeTargetAndDemand

#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Unconditionally ensure that a valid FHT8V TRV command frame has been computed and stored.
bptr = FHT8VTXCommandArea
gosub FHT8VCreateValveSetCmdFrame
#endif


; Initialise the 'random' generator from the input values and other things.
; This does not discard any current random state, but should add some entropy to it.
; There probably isn't much real entropy but we can for example use the environmental inputs.
seedRandWord:
    ; Fold in bits from the internal temperature sensor, and supply voltage, and external temperature!
    readinternaltemp IT_RAW_L, 0, tempW0
    randWord = randWord - tempW0 ^ currentTempC16
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
    random randWord ; churn
    ; Read directly from LDR ADC (if present) to get as much noise as possible.
    readadc10 INPUT_LDR, tempW0
    randWord = randWord ^ tempW0
#endif
    ; TODO: fold in some non-volatile state from EEPROM and maybe store back.


low LED_HEATCALL ; Send low after (most) initialisation finished.


; In the absence of a CLI, wait a little while for the user to set the time...
#ifndef SUPPORT_CLI
#ifdef SERTXD_STATUS_REPORTS
; Make a brief status report (a single line, terminated with CRLF, sections separated with ";") on sertxd.
gosub SertxdStatusReport
_InitTimeReq:
sertxd ("HH MM?", 13,10)
SERRXD [30000,_InitTimeReqTimeout], #B0, #B1 ; Wait a little while for HH MM to be supplied.
if B0 > 23 OR B1 > 59 then goto _InitTimeReq ; Try again on bad input
tempB3 = B1 % 10
SPI_DATAB = B1 / 10 * 16 + tempB3 ; SPI_DATAB is now BCD minutes
tempB3 = B0 % 10
B1 = B0 / 10 * 16 + tempB3 ; B1 is now BCD hours
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
gosub DS1306SetBCDHoursMinutes ; Set RTC from B1:SPI_DATAB.  (Should maybe stop and restart clock...)
#else
#error Needs RTC support!
#endif
_InitTimeReqTimeout:
reconnect
gosub SertxdStatusReport
#endif
#endif


; Final RTC setup, if any...
; ...and capture current time just before starting first scheduling round.
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
gosub DS1306ReadBCDSecondsB0
; Panic if RTC not connected (typically reads $ff) or not otherwise responding appropriately.
if B0 > $59 then panic
TIME_LSD = B0
#else
TIME_LSD = time
#endif
; Skip attempt to do any work in first likely-truncated second.
goto schedule


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
mainLoop:
    slowOpDone = 0 ; Set to 1 by slow operations so further slow operations should be bypassed on this cycle to avoid overrun...

#ifdef USE_MODULE_FHT8VSIMPLE_TX
    ; FHT8V comms is highest priority (if in use) because of tight timing requirements.
    gosub TalkToFHT8V
#endif

    ; Schedule UI interaction regularly (every other second, whether time in binary or BCD).
    ; Nearly top priority.
    tempB0 = TIME_LSD & 1
    if tempB0 = 0 then
        ; Indicate/adjust mode.
        ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
        ; Uses button held down to toggle isWarmMode state. (System starts in 'frost' state.)
        ; Schedules update to TVR and boiler ASAP on change of mode, for user responsiveness.
        ; May set slowOpDone if taken a while in the UI code.
        gosub pollShowOrAdjustMode
    endif

    ;debug ; Can be a handy spot to inspect memory...

    ; If no jobs then go back to sleep ASAP...
    if jobsPending = 0 then goto schedule

    ; If already done significant work then postpone low-priority jobs.
    if slowOpDone = 1 then goto schedule

    tempB0 = jobsPending & MASK_JP_TEMP
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_TEMP ; Clear the pending status
        ; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
        gosub getTemperature ; Very slow with DS18B20 (~700ms).
        randWord = randWord ^ currentTempC16
        random randWord ; stir
        slowOpDone = 1 ; Will have eaten up lots of time...
        goto schedule
    endif

#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
    tempB0 = jobsPending & MASK_JP_OLDR
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_OLDR ; Clear the pending status
        ; Check potential occupancy, setting isRoomLit 1 if sufficient for activity else 0.
        gosub getRoomInUseFromLDR
        ; Stir the random-number pot with the current light intensity...
        randWord = randWord ^ tempB0
        random randWord ; stir
        goto schedule
    endif
#endif

    tempB0 = jobsPending & MASK_JP_HTCL
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_HTCL ; Clear the pending status
        ; Compute (about once per minute) new targets and outputs and TRV/boiler settings.
        setfreq CLOCK_SPEED_MAX ; computeTargetAndDemand may need lots of CPU, so run at full tilt to finish ASAP.
        gosub computeTargetAndDemand
        setfreq CLOCK_SPEED_NORMAL
        ; Synchronously adjust boiler call-for-heat output.
#ifdef BOILER_HUB
        if boilerCountdownS != 0 then ; Remote calls for heat are still active.
            high OUT_HEATCALL
        else
#endif
            if TRVPercentOpen != 0 then ; Local call for heat given local TRV is at least partly open/on.  (TODO: modulating!)
                high OUT_HEATCALL
            else ; Stop calling for heat from the boiler.
                low OUT_HEATCALL
            endif
#ifdef BOILER_HUB
        endif
#endif
        goto schedule
    endif

#ifndef BOILER_HUB ; Extra call to boiler for heat.
#ifdef USE_MODULE_FHT8VSIMPLE_TX
    tempB0 = jobsPending & MASK_JP_HTC2
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_HTC2 ; Clear the pending status.
        ; Do twice-per-minute re-send of the TRV command with a randomised delay from cycle start to help avoid clashes with other senders.
        ; ONLY do this if this node is not itself not a boiler hub (with no one listening)
        ; AND if this unit actually wants to call for heat to avoid shouting down nodes that do
        ; AND if the rad valve has actually been sent a command to open at least partially (which also implies sync with the valve).
        if TRVPercentOpen != 0 AND FHT8V_isValveOpen != 0 then
            ; Push transmission to late in the second and spread start time around
            ; to try to avoid always falling into the boiler node's non-RX time.
#ifdef KEEP_ELAPSED_TIME_ACCURATE
            pause 288
#else
            nap 4
#endif
            tempB0 = randMSB min 1 ; Ensure non-zero.
            pause tempB0 ; Spread out the transmission times...
            setfreq CLOCK_SPEED_MAX
            bptr = FHT8VTXCommandArea
            gosub FHT8VTXFHTQueueAndTwiceSendCmd
            slowOpDone = 1
            setfreq CLOCK_SPEED_NORMAL
        endif
        goto schedule
    endif
#endif
#endif

#ifdef SERTXD_STATUS_REPORTS
    tempB0 = jobsPending & MASK_JP_STAT
    if tempB0 != 0 then
        jobsPending = jobsPending ANDNOT MASK_JP_STAT ; Clear the pending status.
        gosub SertxdStatusReport
        slowOpDone = 1 ; Will have eaten lots of wall-clock time...
        goto schedule
    endif
#endif

    ; Clear unserviceable job(s).
    jobsPending = 0

schedule: ; Do general job scheduling (quickly) for next cycle just before the end of this loop.

    ; Deal with any per-second counters/timers.
#ifdef BOILER_HUB
    if boilerCountdownS > 0 then
        dec boilerCountdownS
    else if TRVPercentOpen = 0 then
        low OUT_HEATCALL ; Extra fast path to turn boiler off ASAP to try to avoid running much with no TRVs open.
    endif
#endif

    ; Schedule slow/occasional/non-time-critical tasks over a major cycle (~1 minute).
    ; Note that when multiple jobs are queued at once then handling of lower-priority ones will be delayed.
#ifdef TIME_LSD_IS_BINARY
    tempB0 = TIME_LSD & 63 ; close to a minute cycle, values from 0 to $3f.
#else
    tempB0 = TIME_LSD ; exactly a minute cycle, BCD values from $00 to $59.
#endif
    if tempB0 = 0 then ; Start of the minute cycle.
        ; Queue up all low priority jobs.
        jobsPending = $ff

        ; TODO: Deal with any per-minute counters/timers/operations.

#ifdef SUPPORT_SINGLETON_SCHEDULE
        ; If we're in the minute for a programmed schedule change, act on it.
        gosub checkUserSchedule
#endif
    endif

mainLoopCoda: ; Tail of main loop...

    ; Sleep in lowest-power mode that we can for as long as we reasonably can,
    ; attempting to align the end of the cycle with the ticking over of wallclock seconds.
    ; Sleep with all LEDs off.

    ; Wait for elapsed time to roll...

    ;debug ; Can be a handy spot to inspect memory...

#ifdef BOILER_HUB ; Start listening for remote TRV nodes calling for heat.
    gosub SetupToEavesdropOnFHT8V
#endif

    ; Churn the random value to fill time and make it more randomy...  B^>
    random randWord

    ; Can take energy-saving initial nap if no slow op done.  (And if not transmitting at the start of every cycle.)
    ; Could alternatively check not already in second half of cycle if 1Hz input available.
#ifndef BOILER_HUB ; RX mode will consume more power than the PICAXE...
#ifndef IGNORE_FHT_SYNC ; Every cycle is slow: don't try this.
#ifndef KEEP_ELAPSED_TIME_ACCURATE ; Only worth doing if low-power mode is available.
    if slowOpDone = 0 then
#ifdef 18M2
        randWord = randWord - time ; Entropy from slippage between RTC and internal clock...
#endif
        random randWord
        disablebod
        nap 4 ; ~288ms.
        enablebod
    endif
#endif
#endif
#endif

    do
        ; Wait for seconds of wall-clock/elapsed time to roll, and capture new value.
        ; As soon as the elapsed time rolls over, start new main loop cycle.
        ; In the interim, fill time with radio RX and/or energy saving sleeps and/or random number churn, ...
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
#ifdef DS1306RTC_1HZ_AVAILABLE ; Can use RTC_1HZ_PIN...
        if RTC_1HZ_PIN = 0 then takenap ; Seconds not rolled yet (in second half of cycle); need not expensively fetch time from RTC.
#endif
        gosub DS1306ReadBCDSecondsB0 ; B0 = BCD seconds.
#else
        B0 = time ; Internal elapsed time measure least-significant byte (binary).
#endif
        ; B0 is putative new value for TIME_LSD...
        if B0 = TIME_LSD then takenap ; Second has not yet rolled.

        ; Check for and act on missed ticks eg force resync.
        tempB1 = TIME_LSD + 1 ; Expected new value for TIME_LSD given previous.
        if tempB1 != B0 then
#ifndef TIME_LSD_IS_BINARY ; Extra corrections for BCD increment and minute roll...
            tempB2 = tempB1 & $f
            if tempB2 = $a then : tempB1 = tempB1 + 6 : endif
            if tempB1 = $60 then : tempB1 = 0 : endif
            if tempB1 != B0 then
#endif
#ifdef DEBUG
                inc missedTickCount ; Boo, hiss, missed a(nother) tick!
#endif

#ifdef USE_MODULE_FHT8VSIMPLE_TX
                ; Set back to initial unsynchronised state and force resync with TRV.
                gosub FHT8VSyncAndTXReset
#endif

                ;debug ; MISSED AT LEAST ONE TICK

#ifndef TIME_LSD_IS_BINARY
            endif
#endif
        endif

        ; TODO if (masked) time rolls to a smaller number then trigger a minute counter; robust even if individual seconds get missed.
        TIME_LSD = B0
        exit ; Break out of loop waiting for seconds roll-over.


        ; Sleep/pause a little, saving energy if possible.
        ; May be able to sleep in longer chunks if NOT doing radio RX and NOT yet at half-second mark...
        ; Keep under 50ms to control timing jitter at start of next cycle.
takenap:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
        pause 36
#else
        disablebod
        nap 1 ; ~36ms.
        enablebod
#endif


#ifdef BOILER_HUB ; Listen for remote TRV nodes calling for heat.
        ; Listen/RX radio comms if appropriate.
        if boilerCountdownS != BOILER_CALL_TIMEOUT_S then ; Only listen if not just heard remote call for heat.
            gosub RFM22ReadStatusBoth
            if SPI_DATAB >= $80 then ; Got sync from incoming FHT8V message.

#ifdef RFM22_SYNC_ONLY_BCFH
                ; Force boiler on for a while...
                boilerCountdownS = BOILER_CALL_TIMEOUT_S

                ; Stop listening so as to save energy.
                gosub StopEavesdropOnFHT8V
#else
#error Need to decode frame and check for (a) supported TRV and (b) valve > 0%.
#endif

            else if tempB2 >= $80 then ; RX FIFO overflow/underflow: give up and restart...
                gosub SetupToEavesdropOnFHT8V ; Restart listening...
            endif
        endif
#endif

    loop

#ifdef BOILER_HUB ; Stop listening for remote TRV nodes calling for heat.
    gosub StopEavesdropOnFHT8V
#endif

goto mainLoop ; end of main loop


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


#ifdef SUPPORT_SINGLETON_SCHEDULE
#ifdef LEARN_BUTTON_AVAILABLE ; OPTIONAL ON V0.09 PCB1
; Called when "LEARN" button is activated.
; If pressed while in frost mode then ensure schedule is disabled (set hour values to $ff).
; Else ensure schedule is set to go into warm mode in 24h from now and off again 1h later.
; TODO: minimise EEPROM writes, at least in the simple case that the learn button is held down.
handleLearnButton:
    if isWarmMode = 0 then ; Not in warm mode so erase schedule.
        read EEPROM_SINGLE_PROG_ON_HH, B0 ; Check 'on' hour as proxy for both 'on' and 'off' times.
        if B0 != $ff then
            write EEPROM_SINGLE_PROG_ON_HH, $ff
            write EEPROM_SINGLE_PROG_OFF_HH, $ff
        endif
    else ; Set schedule (if not already present).
        gosub getBinaryHHMMFromRTC ; time now B0:B1
        read EEPROM_SINGLE_PROG_ON_MM, tempB2, tempB3 ; tempB3:tempB2 time
        if B0 != tempB3 OR B1 != tempB2 then
            write EEPROM_SINGLE_PROG_ON_MM, B1, B0
        endif
        ; Have 'off' set to one hour after 'on'.
        inc B0
        if B0 > 23 then : B0 = 0 : endif
        read EEPROM_SINGLE_PROG_OFF_MM, tempB2, tempB3 ; tempB3:tempB2 time
        if B0 != tempB3 OR B1 != tempB2 then
            write EEPROM_SINGLE_PROG_OFF_MM, B1, B0
        endif
    endif
    return
#endif
#endif

#ifdef SUPPORT_SINGLETON_SCHEDULE
; Get RTC's binary hours (0--24) into B0 and binary minutes (0--59) in B1.
; SPI_DATAB, tempB1 are destroyed.
getBinaryHHMMFromRTC:
#ifdef USE_MODULE_DS1306RTCSPISIMPLE
    gosub DS1306ReadBCDHoursMinutes ; B0:SPI_DATAB
    gosub BCDtoBinary
    tempB1 = B1 ; tempB1 is now binary hours
    B0 = SPI_DATAB
    gosub BCDtoBinary ; B1 is now binary minutes
    B0 = tempB1 ; B0 is now binary hours
#else
#error NEEDS RTC SUPPORT
#endif
    return
#endif

#ifdef SUPPORT_SINGLETON_SCHEDULE
; To be called once per minute to check if user-scheduled warm/frost (on/off) is due, setting mode if so.
; Destroys B0, B1, tempB1, tempB2, tempB3, SPI_DATAB.
checkUserSchedule:
    gosub getBinaryHHMMFromRTC ; time now B0:B1
    read EEPROM_SINGLE_PROG_OFF_MM, tempB2, tempB3 ; tempB3:tempB2 time
    if B0 = tempB3 AND B1 = tempB2 then
        isWarmMode = 0 ; Programmed off/frost; takes priority over on/warm if same to bias towards energy-saving.
    else
        read EEPROM_SINGLE_PROG_ON_MM, tempB2, tempB3 ; tempB3:tempB2 time
        if B0 = tempB3 AND B1 = tempB2 then
            isWarmMode = 1 ; Programmed on/warm.
        endif
    endif
    return
#endif


#ifdef BOILER_HUB ; Set up radio to listen for remote TRV nodes calling for heat.
SetupToEavesdropOnFHT8V:
    setfreq CLOCK_SPEED_MAX

    ; Clear RX and TX FIFOs.
    SPI_DATAB = $8 ; RFM22REG_OP_CTRL2
    tempB2 = 3 ; FFCLRRX | FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = $8; RFM22REG_OP_CTRL2
    gosub RFM22WriteReg8Bit0

    ; Set FIFO RX almost-full threshold.
    SPI_DATAB = $7e ; RFM22REG_RX_FIFO_CTRL
    tempB2 = 34 ; Less than shortest valid FHT8V frame...
    gosub RFM22WriteReg8Bit

    ; Enable just the RX sync-detect interrupt.
    SPI_DATAB = 5 ; RFM22REG_INT_ENABLE_1
    gosub RFM22WriteReg8Bit0
    SPI_DATAB = 6 ; RFM22REG_INT_ENABLE_2
    tempB2 = $80
    gosub RFM22WriteReg8Bit

    gosub RFM22ClearInterrupts ; Clear any current status.
    gosub RFM22ModeRX ; Start listening...

    setfreq CLOCK_SPEED_NORMAL
    return

StopEavesdropOnFHT8V:
    setfreq CLOCK_SPEED_MAX
    gosub RFM22ModeStandbyAndClearState ; Known state, FIFOs cleared, standby mode.
    setfreq CLOCK_SPEED_NORMAL
    return
#endif



; Poll for user request to toggle frost/warm mode, and flash to indicate state.
; Schedule TX/update to TRV and boiler ASAP on mode change for user responsiveness.
; May set slowOpDone if taken a while in the UI code.
pollShowOrAdjustMode:
    ; Indicate/adjust mode.
    ; Leaves isWarmMode set appropriately and uses LEDs to indicate state/change.
    ; Uses button held down to cycle through FROST | WARM | BAKE states.
    ; (System starts in 'frost' state.)
    if BUTTON_MODE = 1 then
        slowOpDone = 1 ; UI display will eat lots of wall-clock time...
#ifdef SUPPORT_CLI
        reconnect ; Allow new code download while UI button is held down.
#endif
        high LED_HEATCALL
        if isWarmMode = 0 then ; Was in FROST mode, move to WARM.
            isWarmMode = 1
#ifdef SUPPORT_BAKE
            bakeCountdownM = 0
#endif
            gosub bigPause       ; Long flash 'heat call' to indicate now in warm mode.
#ifdef SUPPORT_BAKE
        else if bakeCountdownM = 0 then ; Was in WARM mode, move to BAKE (with full timeout to run).
            bakeCountdownM = BAKE_MAX_M
            gosub bigPause       ; Long then medium flash 'heat call' to indicate now in bake mode.
            low LED_HEATCALL
            gosub mediumPause    ; (Second flash.)
            high LED_HEATCALL
            gosub mediumPause
#endif
        else ; Was in BAKE (if supported, else was in WARM), move to FROST.
            isWarmMode = 0
            gosub mediumPause    ; Medium flash 'heat call' to indicate now in frost mode.
        endif

    else ; Button not pressed: quickly indicate current mode with flash(es), then optional further flash if actually calling for heat.
        if isWarmMode = 1 then
            high LED_HEATCALL    ; Flash 'heat call' to indicate heating mode.

#ifndef LEARN_BUTTON_AVAILABLE
            gosub tinyPause      ; Initial flash always tiny if no 'learn' mode.
#else                            ' Initial flash lengthed if ('on') schedule is set.
            read EEPROM_SINGLE_PROG_ON_HH, B0
            if B0 != $ff then
                gosub mediumPause    ; Initial flash medium with 'on' schedule set.
            else
                gosub tinyPause      ; Initial flash tiny if no 'on' schedule set.
            endif
#endif

            ; Display representation of internal heat-demand value iff in warm mode to avoid confusion.
            if TRVPercentOpen != 0 then
                low LED_HEATCALL
                gosub mediumPause ; Pause before 'calling for heat' flash to separate them visually.
                high LED_HEATCALL ; flash
                gosub tinyPause ; Sum of pauses must not take anything near 1s slot time...

#ifdef SUPPORT_BAKE
                if bakeCountdownM != 0 then ; Third flash if in 'bake' mode.
                    low LED_HEATCALL
                    gosub mediumPause ; Pause before 'bake mode' flash to separate them visually.
                    high LED_HEATCALL ; flash
                    gosub tinyPause ; Sum of pauses must not take anything near full 1s slot time...
                endif
#endif
            endif
        endif
    endif
    low LED_HEATCALL ; Always end frost/warm UI output with LED_HEATCALL off.

#ifdef LEARN_BUTTON_AVAILABLE
        ; Handle learn button if supported and pressed.
        if BUTTON_LEARN_L = 0 then
            gosub handleLearnButton
            high LED_HEATCALL ; Leave heatcall LED on while learn button held down.
        endif
#endif
    return

#ifdef SERTXD_STATUS_REPORTS
; Make a brief status report (a single line, terminated with CRLF, sections separated with ";") on sertxd.
#rem ; Output may look a little like this:
=F0%@18C;T16 36 W255 0 F255 0
=W0%@18C;T16 38 W255 0 F255 0
=W0%@18C;T16 39 W255 0 F255 0
=W0%@18C;T16 40 W16 39 F17 39
=W0%@18C;T16 41 W16 39 F17 39
=W0%@17C;T16 42 W16 39 F17 39
=W20%@17C;T16 43 W16 39 F17 39
=W20%@17C;T16 44 W16 39 F17 39
=F0%@17C;T16 45 W16 39 F17 39
#endrem
SertxdStatusReport:
    sertxd("=") ; Signal start of status line.

    ; Show basic mode (Warm/Frost), valve% and current temp.
    if isWarmMode = 1 then : sertxd("W") : else : sertxd("F") : endif
    sertxd(#TRVPercentOpen, "%@", #currentTempC, "C")

#ifdef SUPPORT_SINGLETON_SCHEDULE
    gosub getBinaryHHMMFromRTC ; time B0:B1
    sertxd(";T", #B0, " ", #B1)
    read EEPROM_SINGLE_PROG_ON_MM, B1, B0
    sertxd(" W", #B0, " ", #B1)
    read EEPROM_SINGLE_PROG_OFF_MM, B1, B0
    sertxd(" F", #B0, " ", #B1)
#endif

#ifdef DEBUG
    ; Show if ticks have been missed.
    if missedTickCount != 0 then : sertxd(";M",#missedTickCount) : endif
#endif

    ; End line.
    sertxd(13,10)
    return
#endif


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
    return

; Take a significant pause, saving energy if possible without losing system timing accuracy.
bigPause:
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 288
#else
    nap 4
#endif
    return


; Get temperature in C in currentTempC (and in 16ths in currentTempC16)
getTemperature:
    readtemp12 TEMP_SENSOR, currentTempC16 ; Takes ~700ms.
    currentTempC = currentTempC16 / 16 ; Convert without rounding (ie truncate).
    ; Force negative temperature to 0 to simplify processing.
    if currentTempC >= 128 then
        currentTempC = 0;
        currentTempC16 = 0;
    endif
    return


; Compute target temperature and set heat demand for TRV and boiler.
; CALL APPROXIMATELY ONCE PER MINUTE TO ALLOW SIMPLE TIME-BASED CONTROLS.
; Inputs are isWarmMode, isRoomLit.
; The inputs must be valid (and recent).
; Values set are targetTempC, TRVPercentOpen.
; This may also prepare data such as TX command sequences for the TRV, boiler, etc.
; This routine may take significant CPU time and can be run fast (high clock speed) if necessary; no I/O is done.
; Will set slowOpDone = 1 if this has to regenerate the FHT8V command.
; Destroys tempB0, tempB1, tempB2.
symbol TRV_MIN_SLEW_PC = 10 ; Minimum slew/error distance; should be larger than smallest temperature-sensor-driven step to be effective.
symbol TRV_MAX_SLEW_PC_PER_MIN = 20 ; Maximum slew rate determining minutes to fully on from off; should usually be larger than TRV_MIN_SLEW_PC.
computeTargetAndDemand:
    ; Compute target.
    if isWarmMode = 0 then ; In frost mode.
        targetTempC = FROST ; No setbacks apply.
#ifdef SUPPORT_BAKE
    else if bakeCountdownM != 0 then ; If (still) in bake mode then use high target.
        dec bakeCountdownM
        targetTempC = WARM + BAKE_UPLIFT ; No setbacks apply.
#endif
    else ; In 'warm' mode with possible setback.
#ifndef OMIT_MODULE_LDROCCUPANCYDETECTION
        ; Set back target temperature a little if room is too dark for activity.
        if isRoomLit = 0 then
            targetTempC = WARM - SETBACK min FROST ; Target must never be below FROST.
        else
            targetTempC = WARM
        endif
#else
        targetTempC = WARM ; No LDR, no setback.
#endif
    endif

    ; Set heat demand with some hysteresis and a hint of proportional control.
    ; Always be willing to turn off quickly, but on slowly (AKA "slow start" algorithm),
    ; and try to eliminate unnecessary 'hunting' which makes noise and uses actuator energy.
    ; If tempB2 is non-zero then a change has been made to TRVPercentOpen.
    tempB2 = 0
    if currentTempC < targetTempC then
        ; Limit value open slew to help minimise overshoot and actuator noise.
        ; This should also reduce nugatory setting changes when occupancy (etc) is fluctuating.
        ; Thus it may take several minutes to turn the radiator fully on,
        ; though probably opening the first 30% will allow near-maximum heat output in practice.
        if TRVPercentOpen != 100 then
            TRVPercentOpen = TRVPercentOpen + TRV_MAX_SLEW_PC_PER_MIN max 100 ; Evaluated strictly left-to-right, so slews at max rate and caps at 100.
            tempB2 = 1 ; TRV setting has been changed.
        endif
    else if currentTempC > targetTempC then
#ifdef SUPPORT_BAKE
        bakeCountdownM = 0 ; Ensure bake mode cancelled immediately if over target (eg when target is BAKE).
#endif
        if TRVPercentOpen != 0 then
            TRVPercentOpen = 0 ; Always force to off immediately when requested.  (Eagerly stop heating to conserve.)
            tempB2 = 1 ; TRV setting has been changed.
        endif
    else
        ; Use currentTempC16 lsbits to set valve percentage for proportional feedback
        ; to provide more efficient and quieter TRV drive and probably more stable room temperature.
        tempB0 = currentTempC16 & $f ; Only interested in lsbits.
        tempB0 = 16 - tempB0 ; Now in range 1 (at warmest end of 'correct' temperature) to 16 (coolest).
        tempB0 = tempB0 * 6 ; Now in range 6 to 96, eg valve nearly shut just below top of 'correct' temperature window.
        ; Reduce spurious valve/boiler adjustment by avoiding movement at all unless current error is significant.
        if tempB0 < TRVPercentOpen then
            tempB1 = TRVPercentOpen - tempB0
            if tempB1 >= TRV_MIN_SLEW_PC then
                if tempB1 > TRV_MAX_SLEW_PC_PER_MIN then
                    TRVPercentOpen = TRVPercentOpen - TRV_MAX_SLEW_PC_PER_MIN ; Cap slew rate.
                else
                    TRVPercentOpen = tempB0
                endif
                tempB2 = 1 ; TRV setting has been changed.
            endif
        else if tempB0 > TRVPercentOpen then
            tempB1 = tempB0 - TRVPercentOpen
            if tempB1 >= TRV_MIN_SLEW_PC then
                if tempB1 > TRV_MAX_SLEW_PC_PER_MIN then
                    TRVPercentOpen = TRVPercentOpen + TRV_MAX_SLEW_PC_PER_MIN ; Cap slew rate.
                else
                    TRVPercentOpen = tempB0
                endif
                tempB2 = 1 ; TRV setting has been changed.
            endif
        endif
    endif

    ; Recompute anything necessary to support TRV activity.
#ifdef USE_MODULE_FHT8VSIMPLE_TX
    ; TODO: force update if command buffer is empty (leading $ff).
    if tempB2 != 0 then
        bptr = FHT8VTXCommandArea
        gosub FHT8VCreateValveSetCmdFrame
        slowOpDone = 1
    endif
#endif
    return

#ifdef USE_MODULE_FHT8VSIMPLE_TX
; Sends 'percentage open' in TRVPercentOpen command to TRV as previously computed by FHT8VCreateValveSetCmdFrame.
; B0, bptr, tempB0, tempB1, SPI_DATAB are destroyed.
; DEBUG: checks that the initial byte is expected RFM22 or FHT8V preamble else will panic.
; Runs at high clock speed as otherwise very slow.
TalkToFHT8V:
    setfreq CLOCK_SPEED_MAX ; Turn on turbo mode else creating the frame takes far too long.

; If IGNORE_FHT_SYNC is defined then ignore the FHT8V sync procedure and send every second (which is wasteful of resources but may help with debugging).
#ifdef IGNORE_FHT_SYNC ; Dumb and wasteful (and possibly not legal in terms of ISM duty cycle) but can help with debugging...
    syncedWithFHT8V = 1 ; Pretend in sync always.
    bptr = FHT8VTXCommandArea
    gosub FHT8VQueueCmdViaRFM22Bptr
    setfreq CLOCK_SPEED_NORMAL
    gosub RFM22TXFIFO ; Send it (once, slow interaction w/ RFM22B for robustness)!
    setfreq CLOCK_SPEED_MAX
    gosub RFM22ModeStandbyAndClearState
#else ; Use FHT8V sync procedure and keep TX duty cycle low at ~0.1%.

    gosub FHT8VPollSyncAndTX ; Manage comms with TRV

    bptr = FHT8VTXCommandArea
    if @bptr = $ff AND slowOpDone = 0 then ; Sync complete: needs real command in buffer ASAP when not running too late.
        gosub FHT8VCreateValveSetCmdFrame ; Force frame to be recomputed now...
        slowOpDone = 1
    endif

#endif

    setfreq CLOCK_SPEED_NORMAL
    return
#endif ; USE_MODULE_FHT8VSIMPLE_TX






; TODO
; DHD20130313: allow simple built-in schedule and maybe reset RTC to noon if button is held down at power-up (or allow stub program to set RTC then reload this, at a pinch).
; DHD20130312: create simple command-line interface (will "disconnect" except at boot and while button held down).
; DHD20130301: implement weekly 'descale' operation (when room not dark!).
; DHD20130228: create 'learn' function that (if in warm mode) repeats 'warm' every 24h for 1h from push of 'learn' button, else if in frost mode cancels; manual operation as usual remains possible.  Maybe 2 buttons for 2 independent heat programmes.
; DHD20130227: allow wired-OR input on boiler node to call for heat (from OUT_HEATCALL on some/all TRV nodes as required, eg opto-isolated).
; DHD20130223: use the calibadc command periodically to estimate supply voltage, eg to limit clock speed and/or warn of low batteries and/or shutdown gracefully.


; RECENT CHANGES
; DHD20130408: trimming excess code to squeeze in learn/status support.
; DHD20130408: allowing generation of status summary once per minute.
; DHD20130405: creating simple singleton (1-on, 1-off) schedule triggered in first second of specified HH:MM, also to work with simple 'learn' mode.
; DHD20130405: made boost mode optional, to conserve code space.
; DHD20130331: knocked down 'warm' target 1C after seeing 16WW gas consumption figures for last 3M!
; DHD20130330: delay sending extra calls for heat for boiler node's benefit unless valve has already been sent command to open (to avoid boiler running with TRV closed).
; DHD20130329: allowing boiler to be turned off faster (by boiler node) when no call for heat detected, so as to spend less time running with all TRVs closed.
; DHD20130321: testing use of 1Hz RTC output to reduce power consumption in idle portion of loop; down to ~350uA.
; DHD20130318: tweaked to save energy in coda of quiet loops, while reducing timing jitter that can cause FHT8V problems.
; DHD20130311: implementing slowOpDone to help easily avoid attempting to do multiple slow things in one cycle.
; DHD20130228: split out per-node config into separate prepended header files.
; DHD20130227: integrating RX code to listen to remote TRVs' calls for heat if in BOILER_HUB mode (not exclusive with having own local TRV).
; DHD20130227: introduced 'bake' mode that sets a high target temperature for a short while.
; DHD20130226: scheduling extra wireless TX at randomised offset to reduce risk of boiler node getting into anti-sync with TRV nodes.
; DHD20130226: temporary ugly hack (RFM22_SYNC_ONLY_BCFH): omitting RFM22-friendly aaaaaaaa preamble when not calling for heat so boiler node need only detect sync or time out.
; DHD20130225: minimum and maximum TRV slew rates now implements to minimise overshoot and noise, and to conserve batteries and heating.
; DHD20130224: split FHT8V message encoding from TX, and does the former only on a change.
; DHD20130225: now only shows 'heat call' flash if user has selected 'warm' mode; will request silently if necessary for frost protection.
; DHD20130225: only turning TRV on relatively slowly ("slow start") but off quickly to conserve and limit noise and overshoot.
; DHD20130225: only recomputing targets and outputs about once per minute to allow time-based control.
; DHD20130223: first attempt to reduce spurious TRV hunting/noise on small temperature changes/noise; no time element yet.
; DHD20130222: enabled RTC to improve timing (NB: setup check spotted missing CE connection on stripboard!).
; DHD20130221: added 0xaaaaaaaa RFM22B-friendly pre-preamble at Mike Stirling's suggestion.
; DHD20130218: freed up B.1 and B.4 to allow use of i2c peripherals, relocating LED_HEATCALL from B.1 to B.7. (r417)
; DHD20130218: currently assumes presence of DS18B20 1-wire temp sensor, but only good down to 3V so may need to be able to use alternative.
; DHD20130212: for now transmits every second to be heard by FHT8V TRV, wasting energy, etc!
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

; ****** BCDtools.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; BCD arithmetic tools.

#ifdef USE_MODULE_BCDTOOLS ; Only use content if explicitly requested.

; Convert the BCD value in B0 to binary in B1.
; B0 is not altered.
BCDtoBinary:
    B1 = B0 & $f
    B1 = B0 / 16 * 10 + B1
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

; ****** DS1306-RTC-SPI-simple.inc.bas ****** in module library
; Basic support for DS1306 2V--5V RTC in SPI mode.
; Appendable PICAXE basic fragment.



; Dependencies:
; Needs SPISimple module loaded (and all of its dependencies satisfied).
; symbol DS1306_CE_O ; output bit


; NOTE: 1Hz output signal appears to be high for the 1st half of each second (DHD20130318) and enabled by default (bit 2 in reg $f).


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

#rem
; Reads the seconds register (in BCD, from 0--$59) into SPI_DATAB.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSeconds:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclock
    low DS1306_CE_O
    return
#endrem

; Reads the seconds register (in BCD, from 0--$59) into B0.
; Minimal SPI interaction to do this, so reasonably quick.
DS1306ReadBCDSecondsB0:
    high DS1306_CE_O
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftin_byte_MSB_postclB0
    low DS1306_CE_O
    return

; Reads the hours and minutes registers (in BCD, 0--$23 and 0--$59) into B0 and SPI_DATAB respectively.
DS1306ReadBCDHoursMinutes:
    high DS1306_CE_O
    B0 = 1
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftin_byte_MSB_postclB0
    SPI_DATAB = B0
    gosub SPI_shiftin_byte_MSB_postclB0
    low DS1306_CE_O
    return

; Set hours and minutes registers (in BCD, 0--$23 and 0--$59) from B1 and SPI_DATAB respectively.
DS1306SetBCDHoursMinutes:
    high DS1306_CE_O
    B0 = 1
    gosub SPI_shiftout_byte_1MSB_preclB0
    gosub SPI_shiftout_byte_MSB_preclock ; Write SPI_DATAB.
    B0 = B1
    gosub SPI_shiftout_byte_MSB_preclB0 ; Write B1.
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
; TX and RX elements can be enabled separately to preserve code space.

; Many thanks to Mike Stirling http://mikestirling.co.uk/2012/10/hacking-wireless-radiator-valves-with-gnuradio/
; for register settings, the 200us encoding, and lots of hand-holding!

; RECENT CHANGES
; DHD20130324: No longer try to send actual TRVPercentOpen on final sync (cmd 0) in FHT8VPollSyncAndTX: anything other than zero seems to lock up FHT8V-3 units.
; DHD20130225: created separate FHT8VQueueCmdViaRFM22Bptr routine to allow generation to be separated from TX.
; DHD20130224: added 0xff postamble to transmitted frame to be easier to capture by RFM22/PICAXE.
; DHD20130224: creating FHT8VCreate200usBitStreamBptr with bptr base to allow possibility of cacheing, etc.
; DHD20130223: using 0xaacccccc RX sync word (end of RFM22 pre-preamble and start of FHT preamble) for robustness.
; DHD20130223: turned down transmission power: may have to make setting conditional on whether RFM23 is being used instead.


; Dependencies (for USE_MODULE_FHT8VSIMPLE_TX, transmit side, no I/O)
; symbol FHT8V_HC1 ; House code 1, constant or (byte) register.
; symbol FHT8V_HC2 ; House code 2, constant or (byte) register.
; #define FHT8V_ADR_USED (optional) ; If true then FHT8V_ADR used, else assumed 0 (multicast).
; symbol FHT8V_ADR (optional) ; Sub-address, constant or (byte) register.
; symbol FHT8V_CMD ; Constant or (usually) command byte register.
; symbol FHT8V_EXT ; Constant or (usually) command extension byte register.
; symbol FHT8V_RFM22_Reg_Values ; start address in EEPROM for register setup values.
; #define DEBUG (optional) ; enables extra checking, eg during unit tests.
; #define RFM22_IS_ACTUALLY_RFM23 (optional) ; indicates that RFM23B module is being used in place of RFM22B.
; #define USE_MODULE_RFM22RADIOSIMPLE (optional) ; to include some specific RFM22 support.
; symbol syncedWithFHT8V (bit, true once synced)
; symbol FHT8V_isValveOpen (bit, true if node has sent command to open TRV)
; symbol syncStateFHT8V (byte, internal)
; symbol halfSecondsToNextFHT8VTX (byte)
; symbol TRVPercentOpen (byte, in range 0 to 100) ; valve open percentage to convey to FHT8V
; symbol slowOpDone (bit) ; set to 1 if a routine takes significant time
; symbol FHT8VTXCommandArea (byte block) ; for FHT8V outgoing commands
; panic: ; Label for any routine to jump to to abort system operation as safely as possible.





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
EEPROM FHT8V_RFM22_Reg_Values, ($6,0) ; Disable default chiprdy and por interrupts.
; EEPROM ($8,0) ; RFM22REG_OP_CTRL2: ANTDIVxxx, RXMPK, AUTOTX, ENLDM
#ifndef RFM22_IS_ACTUALLY_RFM23
; For RFM22 with RXANT tied to GPIO0, and TXANT tied to GPIO1...
EEPROM ($b,$15, $c,$12) ; DISABLE FOR RFM23
#endif
; 0x30 = 0x00 - turn off packet handling
; 0x33 = 0x06 - set 4 byte sync
; 0x34 = 0x08 - set 4 byte preamble
; 0x35 = 0x10 - set preamble threshold (RX) 2 nybbles / 1 bytes of preamble.
; 0x36-0x39 = 0xaacccccc - set sync word, using end of RFM22-pre-preamble and start of FHT8V preamble.
EEPROM ($30,0, $33,6, $34,8, $35,$10, $36,$aa, $37,$cc, $38,$cc, $39,$cc)

; From AN440: The output power is configurable from +13 dBm to Ð8 dBm (Si4430/31), and from +20 dBM to Ð1 dBM (Si4432) in ~3 dB steps. txpow[2:0]=000 corresponds to min output power, while txpow[2:0]=111 corresponds to max output power.
; The maximum legal ERP (not TX output power) on 868.35 MHz is 25 mW with a 1% duty cycle (see IR2030/1/16).
;EEPROM ($6d,%00001111) ; RFM22REG_TX_POWER: Maximum TX power: 100mW for RFM22; not legal in UK/EU on RFM22 for this band.
;EEPROM ($6d,%00001000) ; RFM22REG_TX_POWER: Minimum TX power (-1dBm).
#ifndef RFM22_IS_ACTUALLY_RFM23
    #ifndef RFM22_GOOD_RF_ENV
    EEPROM ($6d,%00001101) ; RFM22REG_TX_POWER: RFM22 +14dBm ~25mW ERP with 1/4-wave antenna.
    #else ; Tone down for good RF backplane, etc.
    EEPROM ($6d,%00001001)
    #endif
#else
    #ifndef RFM22_GOOD_RF_ENV
    EEPROM ($6d,%00001111) ; RFM22REG_TX_POWER: RFM23 max power (+13dBm) for ERP ~25mW with 1/4-wave antenna.
    #else ; Tone down for good RF backplane, etc.
    EEPROM ($6d,%00001011)
    #endif
#endif

EEPROM ($6e,40, $6f,245) ; 5000bps, ie 200us/bit for FHT (6 for 1, 4 for 0).  10485 split across the registers, MSB first.
EEPROM ($70,$20) ; MOD CTRL 1: low bit rate (<30kbps), no Manchester encoding, no whitening.
EEPROM ($71,$21) ; MOD CTRL 2: OOK modulation.
EEPROM ($72,$20) ; Deviation GFSK. ; WAS EEPROM ($72,8) ; Deviation 5 kHz GFSK.
EEPROM ($73,0, $74,0) ; Frequency offset
; Channel 0 frequency = 868 MHz, 10 kHz channel steps, high band.
EEPROM ($75,$73, $76,100, $77,0) ; BAND_SELECT,FB(hz), CARRIER_FREQ0&CARRIER_FREQ1,FC(hz) where hz=868MHz
EEPROM ($79,35) ; 868.35 MHz - FHT
EEPROM ($7a,1) ; One 10kHz channel step.
; RX-only
#ifdef USE_MODULE_FHT8VSIMPLE_RX ; RX-specific settings, again c/o Mike S.
EEPROM ($1c,0xc1, $1d,0x40, $1e,0x0a, $1f,0x03, $20,0x96, $21,0x00, $22,0xda, $23,0x74, $24,0x00, $25,0xdc) ; 0$1c was 0xc1
EEPROM ($2a,0x24)
EEPROM ($2c,0x28, $2d,0xfa, $2e,0x29)
EEPROM ($69,$60) ; AGC enable: SGIN | AGCEN
#endif
; Terminate the initialisation data.
EEPROM ($ff)

#rem ; DHD20130226 dump
     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
00 : 08 06 20 20 00 00 00 00 00 7F 06 15 12 00 00 00
01 : 00 00 20 00 03 00 01 00 00 01 14 00 C1 40 0A 03
02 : 96 00 DA 74 00 DC 00 1E 00 00 24 00 28 FA 29 08
03 : 00 00 0C 06 08 10 AA CC CC CC 00 00 00 00 00 00
04 : 00 00 00 FF FF FF FF 00 00 00 00 FF 08 08 08 10
05 : 00 00 DF 52 20 64 00 01 87 00 01 00 0E 00 00 00
06 : A0 00 24 00 00 81 02 1F 03 60 9D 00 01 0B 28 F5
07 : 20 21 20 00 00 73 64 00 19 23 01 03 37 04 37
#endrem
#endif



#ifdef USE_MODULE_FHT8VSIMPLE_TX ; Only use TX support content if explicitly requested.

#ifdef USE_MODULE_RFM22RADIOSIMPLE ; RFM22 module must be loaded to use this.

; Call once per second to manage initial sync and subsequent comms with FHT8V valve.
; Requires globals defined that this maintains:
;     syncedWithFHT8V (bit, true once synced)
;     syncStateFHT8V (byte, internal)
;     halfSecondsToNextFHT8VTX (byte)
; Use globals maintained/set elsewhere / shared:
;     TRVPercentOpen (byte, in range 0 to 100) valve open percentage to convey to FHT8V
;     slowOpDone (bit) set to 1 if this routine takes significant time
;     FHT8VTXCommandArea (byte block) for FHT8V outgoing commands
; Can be VERY CPU AND I/O INTENSIVE so running at high clock speed may be necessary.
; If on exit the first byte of the command buffer has been set to $ff
; then the command buffer should immediately (or within a few seconds)
; have a valid outgoing command put in it for the next scheduled transmission to the TRV.
; The command buffer can then be updated whenever required for subsequent async transmissions.
FHT8VPollSyncAndTX:
    if syncedWithFHT8V = 0 then
        ; Give priority to getting in sync over all other tasks, though pass control to them afterwards...
        ; NOTE: startup state, or state to force resync is: syncedWithFHT8V = 0 AND syncStateFHT8V = 0
        if syncStateFHT8V = 0 then
            ; Starting sync process.
            syncStateFHT8V = 241
        endif

        if syncStateFHT8V >= 3 then
            ; Generate and send sync (command 12) message immediately.
            FHT8V_CMD = $2c ; Command 12, extension byte present.
            FHT8V_EXT = syncStateFHT8V
            syncStateFHT8V = syncStateFHT8V - 2
            bptr = FHT8VTXCommandArea
            gosub FHT8VCreate200usBitStreamBptr
            bptr = FHT8VTXCommandArea
            gosub FHT8VTXFHTQueueAndTwiceSendCmd ; SEND SYNC
            ; On final tick set up time to sending of final sync command.
            if syncStateFHT8V = 1 then
                ; Set up timer to sent sync final (0) command
                ; with formula: t = 0.5 * (HC2 & 7) + 4 seconds.
                halfSecondsToNextFHT8VTX = FHT8V_HC2 & 7 + 8 ; Note units of half-seconds for this counter.
            endif

            slowOpDone = 1 ; Will have eaten up lots of time...
        else ; < 3 so waiting to send sync final (0) command...

            if halfSecondsToNextFHT8VTX >= 2 then
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX - 2
            endif

            if halfSecondsToNextFHT8VTX < 2 then

                ; Set up correct delay to this TX and next TX dealing with half seconds if need be.
                gosub FHT8VTXGapHalfSeconds
                if halfSecondsToNextFHT8VTX = 1 then ; Need to pause an extra half-second.
                    pause 500
                endif
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX + tempB0

                ; Send sync final command.
                FHT8V_CMD = $20 ; Command 0, extension byte present.
                FHT8V_EXT = 0 ; DHD20130324: could set to TRVPercentOpen, but anything other than zero seems to lock up FHT8V-3 units.
                bptr = FHT8VTXCommandArea
                gosub FHT8VCreate200usBitStreamBptr
                bptr = FHT8VTXCommandArea
                gosub FHT8VTXFHTQueueAndTwiceSendCmd ; SEND SYNC FINAL

                ; Assume now in sync...
                syncedWithFHT8V = 1

                ; Mark buffer as empty to get it filled with the real TRV valve-setting command immediately.
                poke FHT8VTXCommandArea, $ff

                slowOpDone = 1 ; Will have eaten up lots of time already...
            endif
        endif

    else ; In sync: count down and send command as required.
            if halfSecondsToNextFHT8VTX >= 2 then
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX - 2
            endif

            if halfSecondsToNextFHT8VTX < 2 then

                ; Set up correct delay to this TX and next TX dealing with half seconds if need be.
                gosub FHT8VTXGapHalfSeconds
                if halfSecondsToNextFHT8VTX = 1 then ; Need to pause an extra half-second.
                    pause 500
                endif
                halfSecondsToNextFHT8VTX = halfSecondsToNextFHT8VTX + tempB0

                ; Send already-computed command to TRV.
                ; Queue and send the command.
                bptr = FHT8VTXCommandArea
                gosub FHT8VTXFHTQueueAndTwiceSendCmd

                ; Assume that command just sent reflects the current TRV inetrnal model state.
                ; If TRVPercentOpen is not zero assume that remote valve is now open(ing).
                if TRVPercentOpen = 0 then : FHT8V_isValveOpen = 0 : else : FHT8V_isValveOpen = 1 : endif

                slowOpDone = 1 ; Will have eaten up lots of time...
            endif
    endif
    return


; Call to reset comms with FHT8V valve and force resync.
; Resets values to power-on state so need not be called in program preamble if variables not tinkered with.
; Requires globals defined that this maintains:
;     syncedWithFHT8V (bit, true once synced)
;     FHT8V_isValveOpen (bit, true if this node has last sent command to open valve)
;     syncStateFHT8V (byte, internal)
;     halfSecondsToNextFHT8VTX (byte).
FHT8VSyncAndTXReset:
    syncedWithFHT8V = 0
    syncStateFHT8V = 0
    halfSecondsToNextFHT8VTX = 0
    FHT8V_isValveOpen = 0
    return

; Compute interval (in half seconds) between TXes for FHT8V given FHT8V_HC2.
; (In seconds, the formula is t = 115 + 0.5 * (HC2 & 7) seconds.)
; Result returned in tempB0.
FHT8VTXGapHalfSeconds:
    tempB0 = FHT8V_HC2 & 7 + 230 ; Calculation strictly left-to-right.
    return

; Create FHT8V TRV outgoing valve-setting command frame (terminated with $ff) at bptr.
; The TRVPercentOpen value is used to generate the frame.
; On entry FHT8V_HC1, FHT8V_HC2 (and FHT8V_ADR if used) must be set correctly.
; The generated command frame can be resent indefinitely.
; This is CPU intensive, so can be run at a high clock speed if required.
; Destroys: bptr, tempW0.
FHT8VCreateValveSetCmdFrame:
    FHT8V_CMD = $26 ; Set valve to specified open fraction [0,255] => [closed,open].
    tempW0 = TRVPercentOpen * 255
    FHT8V_EXT = tempW0 / 100 ; Set valve open to desired %age.
#ifdef RFM22_SYNC_ONLY_BCFH
    ; Huge cheat: only add RFM22-friendly pre-preamble if calling for heat from the boiler (TRV not closed).
    ; NOTE: this requires more buffer space and technically we are overflowing the original FHT8VTXCommandArea.
    if TRVPercentOpen != 0 then
        @bptrinc = $aa
        @bptrinc = $aa
        @bptrinc = $aa
        @bptrinc = $aa
    endif
#endif
    goto FHT8VCreate200usBitStreamBptr ; GOSUB CHAIN: gosub FHT8VCreate200usBitStreamBptr return ; For speed and to preserve gosub slots.

; Sends to FHT8V in FIFO mode command bitstream from buffer starting at bptr up until terminating $ff, then reverts to low-power standby mode.
; The trailing $ff is not sent.
; Returns immediately without transmitting if the command buffer starts with $ff (ie is empty).
; (Sends the bitstream twice, with a short (~100ms) pause between transmissions, to help ensure reliable delivery.)
FHT8VTXFHTQueueAndTwiceSendCmd:
    if @bptr = $ff then : return : endif
    gosub FHT8VQueueCmdViaRFM22Bptr
    gosub RFM22TXFIFO ; Send it!
    ; Should nominally pause about 8--9ms or similar before retransmission...
    ; (Though overheads of getting in out of RFM22TXFIFO routine will likely swamp that anyway.)
#rem
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    pause 8
#else
    nap 0
#endif
#endrem
    gosub RFM22TXFIFO ; Re-send it!
    goto RFM22ModeStandbyAndClearState ; GOSUB CHAIN: gosub RFM22ModeStandbyAndClearState return ; For speed and to preserve gosub slots.

; Clears the RFM22 TX FIFO and queues up ready to send via RFM22TXFIFO the $ff-terminated FHT8V command starting at bptr.
; The FHT8V frame may have been previously generated with FHT8VCreate200usBitStream.
; B0, bptr, tempB1 are destroyed.
; This routine does a lot of I/O and can be run at a high clock speed to help bit-band faster.
; This routine does not change the command area or FHT_XXX values.
FHT8VQueueCmdViaRFM22Bptr:
    ; Clear the TX FIFO.
    gosub RFM22ClearTXFIFO
    ; Load bit stream (and preambles) into RFM22 using burst-write mode...
    low RFM22_nSEL_O
    B0 = $ff ; TX FIFO (burst) write to register $7f.
    gosub SPI_shiftout_byte_MSB_preclB0
    ; Send out FHT8V encoded frame.
    do
        B0 = @bptrinc
        if B0 = $ff then exit
        gosub SPI_shiftout_byte_MSB_preclB0
    loop
    high RFM22_nSEL_O
    return

#endif


; Create stream of bytes to be transmitted to FHT80V at 200us per bit, msbit of each byte first.
;
; Byte stream is terminated by $ff byte which is not a possible valid encoding.
; On entry, FHT8V_HC1, FHT8V_HC2, FHT8V_ADR (0 if undefined), FHT8V_CMD and FHT8V_EXT are inputs (and not destroyed if registers).
; On exit, the memory block starting at ScratchMemBlock contains the low-byte, msbit-first bit, $ff terminated TX sequence.
; The maximum and minimum possible encoded message sizes are 35 (all zero bytes) and 45 (all $ff bytes) bytes long.
; Note that a buffer space of at least 46 bytes is needed to accommodate the longest message and the terminator.
; B0, tempB1 are destroyed.
; bptr is pointing to the terminating $ff on exit.
FHT8VCreate200usBitStreamBptr:
    ; Generate preamble.
    ; First 12x 0 bits of preamble, pre-encoded.
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptrinc = $cc
    @bptr = $ff ; Initialise for _FHT8VCreate200usAppendEncBit routine.
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
    B0 = $c + FHT8V_HC1 + FHT8V_HC2 + FHT8V_ADR + FHT8V_CMD + FHT8V_EXT
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

    @bptr = $ff ; Terminate TX bytes.
;sertxd(13,10);
    return

; Appends encoded 200us-bit representation of logical msbit from B0.
; If the most significant bit of B0 (Bit7) is 0 this appends 1100 else this appends 111000
; msb-first to the byte stream being created by FHT8VCreate200usBitStream.
; Does NOT destroy B0.
; bptr must be pointing at the current byte to update on entry which must start off as $ff;
; this will write the byte and increment tempB0 (and write $ff to the new location) if one is filled up.
; Partial byte can only have even number of bits present, ie be in one of 4 states.
; Two least significant bits used to indicate how many bit pairs are still to be filled,
; so initial $ff value (which is never a valid complete filled byte) indicates 'empty'.
; Destroys tempB1.
_FHT8VCreate200usAppendEncBit:
;sertxd(#bit7);
    tempB1 = @bptr & 3 ; Find out how many bit pairs are left to fill in the current byte.
    if bit7 = 0 then ; Appending 1100
        select case tempB1
            case 3 ; Empty target byte (should be $ff currently).
                @bptr = %11001101 ; Write back partial byte (msbits now 1100 and two bit pairs remain free).
            case 2 ; Top bit pair already filled.
                @bptr    = @bptr & %11000000 | %110000 ; Preserve existing ms bit-pair, set middle four bits 1100, one bit pair remains free.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1100 ; Preserve existing ms bit-pairs, set bottom four bits 1100, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            else ; Top three bit pairs already filled.
                @bptrinc = @bptr & %11111100 |     %11 ; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
        endselect
    else ; Appending 111000
        select case tempB1
            case 3 ; Empty target byte (should be $ff currently).
                @bptr = %11100000 ; (one bit pair remains free)
            case 2 ; Top bit pair already filled.
                @bptrinc = @bptr & %11000000 | %111000 ; Preserve existing ms bit-pair, set lsbits to 111000, write back full byte.
                @bptr = $ff ; Initialise next byte for next incremental update.
            case 1 ; Top two bit pairs already filled.
                @bptrinc = @bptr & %11110000 |   %1110; Preserve existing ms bit-pairs, set bottom four bits to 1110, write back full byte.
                @bptr = %00111110 ; Write trailing 00 bits to next byte and indicate 3 bit-pairs free for next incremental update.
            else ; Top three bit pairs already filled.
                @bptrinc = @bptr & %11111100 |     %11; Preserve existing ms bit-pairs, OR in leading 11 bits, write back full byte.
                @bptr = %10001101 ; Write trailing 1000 bits to next byte and indicate 2 bit-pairs free for next incremental update.
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
#ifdef REDUCE_CODE_SPACE_FHT8V ; Reduce code space in return for slightly lower performance.
    gosub _FHT8VCreate200usABEPb ; Original bit 6.
    gosub _FHT8VCreate200usABEPb ; Original bit 5.
    gosub _FHT8VCreate200usABEPb ; Original bit 4.
    gosub _FHT8VCreate200usABEPb ; Original bit 3.
    gosub _FHT8VCreate200usABEPb ; Original bit 2.
    gosub _FHT8VCreate200usABEPb ; Original bit 1.
    gosub _FHT8VCreate200usABEPb ; Original bit 0.
#else
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
#endif
    if bit7 = bit0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    bit7 = bit0 ; Computed parity is in bit 0...
    goto _FHT8VCreate200usAppendEncBit ; GOSUB CHAIN: gosub _FHT8VCreate200usAppendEncBit return ; For speed and to preserve gosub slots.

#ifdef REDUCE_CODE_SPACE_FHT8V
; Shift up one bit while updating parity in bit0, and encode new MSbit.
; Avoids an extra level of stack recursion.
_FHT8VCreate200usABEPb:
    if bit7 = 0 then
        B0 = B0 + B0
    else
        B0 = B0 + B0 + 1
    endif
    goto _FHT8VCreate200usAppendEncBit ; GOSUB CHAIN: gosub _FHT8VCreate200usAppendEncBit return ; For speed and to preserve gosub slots.
#endif


#endif USE_MODULE_FHT8VSIMPLE_TX




#ifdef USE_MODULE_FHT8VSIMPLE_RX ; Only use RX support content if explicitly requested.
; TODO
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
    if tempB0 < 30 then
        isRoomLit = 0
    else if tempB0 > 35 then
        isRoomLit = 1
    endif
    return




#endif
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
; DHD20130312: Using B0 versions of some SPI routines for performance.
; DHD20130309: only reading status reg 1 (#3) in FIFO TX, but also only terminating on ipksent (bit 2); may have fixed 32MHz unreliability problem.
; DHD20130224: testing 'gosub chaining' at tail of subroutines to save gosub slots and possible some time/space.
; DHD20130222: using pause and loop limit in RFM22TXFIFO to avoid lockup in that routine (bashing on SPI too hard) and save some juice?
; DHD20130222: using RFM22ModeStandbyAndClearState at end of init and TXFIFO routines in hope of reducing power consumption (turning interrupts off).

; TODO: see note at end on suggestions for self-check and reset.


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
    goto RFM22ModeStandby ; GOSUB CHAIN: gosub RFM22ModeStandby return ; For speed and to preserve gosub slots.


; Simple test that RFM22 seems to be correctly connected over SPI.
; Returns 0 in SPI_DATAB if RFM22 appears present and correct, else non-zero value for something wrong.
; tempB0 contains device type as read.
; tempB1 contains device version iff device type was read OK.
; Can be called before or after RFM22PowerOnInit.
; Destroys B0.
RFM22CheckConnected:
    B0 = 0 ; device type
    gosub RFM22ReadReg8BitB0
    tempB0 = B0
    if B0 != RFM22_SUPPORTED_DEVICE_TYPE then _RFM22CheckConnectedError
    B0 = 1 ; device version
    gosub RFM22ReadReg8BitB0
    tempB1 = B0
    if B0 != RFM22_SUPPORTED_DEVICE_VERSION then _RFM22CheckConnectedError
    SPI_DATAB = 0 ; All OK.   ; FIXME: change API to return status in B0.
    return
; Error return.
_RFM22CheckConnectedError:
    SPI_DATAB = 1 ; Error value
    return

; Set up a block of RFM22 registers from EEPROM.
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


; Read status (both registers) and clear interrupts.
; Status register 1 is returned in tempB2: 0 indicates no pending interrupts or other status flags set.
; Status register 2 is returned in SPI_DATAB: 0 indicates no pending interrupts or other status flags set.
; Destroys B0 and tempB0.
RFM22ReadStatusBoth:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftin_byte_MSB_preclB0
    tempB2 = B0
    gosub SPI_shiftin_byte_MSB_preclB0
    SPI_DATAB = B0 ; FIXME: change API to skip this
    high RFM22_nSEL_O
    return

; Read/discard status (both registers) to clear interrupts.
; Destroys SPI_DATAB.
RFM22ClearInterrupts:
    low RFM22_nSEL_O
    SPI_DATAB = RFM22REG_INT_STATUS1
    gosub SPI_shiftout_byte_MSB_preclock
    gosub SPI_shiftout_0byte_MSB_pre ; read and discard status 1 quickly.
    gosub SPI_shiftout_0byte_MSB_pre ; read and discard status 2 quickly.
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
    ; Disable all interrupts by (burst) writing 0 to both interrupt-enable registers.  (May help radio power down fully.)
    low RFM22_nSEL_O
    B0 = RFM22REG_INT_ENABLE1
    gosub SPI_shiftout_byte_1MSB_preclB0
    gosub SPI_shiftout_0byte_MSB_pre
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    ; Clear any pending interrupts.  FIXME: may need to be done after disabling ints to avoid races?
    goto RFM22ClearInterrupts ; GOSUB CHAIN: gosub RFM22ClearInterrupts return ; For speed and to preserve gosub slots.

#rem
; Clear RX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearRXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 2 ; FFCLRRX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.
#endrem

; Clear TX FIFO.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ClearTXFIFO:
    SPI_DATAB = RFM22REG_OP_CTRL2
    tempB2 = 1 ; FFCLRTX
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_OP_CTRL2
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.

; Enter standby mode (consume least possible power but retain register contents).
; Destroys SPI_DATAB, B0.
RFM22ModeStandby:
    SPI_DATAB = RFM22REG_OP_CTRL1
    goto RFM22WriteReg8Bit0 ; GOSUB CHAIN: gosub RFM22WriteReg8Bit0 return ; For speed and to preserve gosub slots.

#rem
; Enter 'tune' mode (to enable fast transition to TX or RX mode).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTune:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000010 ; PLLON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.
#endrem

; Enter transmit mode (and send any packet queued up in the TX FIFO).
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeTX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00001001 ; TXON | XTON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

; Enter receive mode.
; Destroys SPI_DATAB, tempB2, B0.
RFM22ModeRX:
    SPI_DATAB = RFM22REG_OP_CTRL1
    tempB2 = %00000101 ; RXON | XTON
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.

#rem
; Append a single byte to the transmit FIFO.
; Does not check for or prevent overflow.
; Byte to write should be in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteByteToTXFIFO:
    SPI_DATAB = RFM22REG_FIFO
    goto RFM22WriteReg8Bit ; GOSUB CHAIN: gosub RFM22WriteReg8Bit return ; For speed and to preserve gosub slots.
#endrem

; Transmit contents of on-chip TX FIFO: caller should revert to low-power standby mode (etc) if required.
; Destroys tempB0, tempB1, tempB2, B0.
; If SPI_DATAB != 0 on exit then packet apparently sent correctly/fully.
; Does not clear TX FIFO (so possible to re-send immediately).
; Note: Reliability possibly helped by early move to 'tune' mode to work other than with default (4MHz) lowish PICAXE clock speeds.
RFM22TXFIFO:
    ;gosub RFM22ModeTune ; Warm up the PLL for quick transition to TX below (and ensure NOT in TX mode).
    ; Enable interrupt on packet send ONLY.
    SPI_DATAB = RFM22REG_INT_ENABLE1
    tempB2 = 4
    gosub RFM22WriteReg8Bit
    SPI_DATAB = RFM22REG_INT_ENABLE2
    gosub RFM22WriteReg8Bit0
    gosub RFM22ClearInterrupts ; Clear any current status...
    gosub RFM22ModeTX ; Enable TX mode and transmit TX FIFO contents.

    ; Each byte in the FIFO takes 1.6ms at 200us/bit, so max 102.4ms for full 64-byte payload.
    ; Whole TX likely to take > 70ms for a typical FHT8V message; avoid bashing SPI too hard!
#ifdef KEEP_ELAPSED_TIME_ACCURATE
    for tempB1 = 0 to 64 ; Should be plenty of time even at max clock rate...
        pause 18 ; May be a fraction of nominal pause time if running at high clock speed.
#else
    for tempB1 = 0 to 8 ; Should be plenty of time even with some wobble on nap timer...
        nap 0 ; Save a little energy...
#endif
        B0 = RFM22REG_INT_STATUS1 ; Read just status reg 1 looking for bit 2 (ipksent) to be set...
        gosub RFM22ReadReg8BitB0
        if bit2 != 0 then exit ; Packet sent...
    next tempB1 ; Spin until packet sent...  COULD POLL INPUT PIN FROM nIRQ FIRST/INSTEAD.
    SPI_DATAB = bit2
    return

#rem
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
#endrem

; Reads a byte from a radio register over SPI.
; Register number in B0 on call (with msb / bit 7 = 0 for read).
; Result is returned in B0.
RFM22ReadReg8BitB0:
    low RFM22_nSEL_O
    gosub SPI_shiftout_byte_MSB_preclB0
    gosub SPI_shiftin_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a byte to a radio register over SPI.
; Register number in SPI_DATAB on call (will be destroyed); MSB is forced to 1 to enforce write mode.
; Data content to write in tempB2.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit:
    low RFM22_nSEL_O
    B0 = SPI_DATAB
    gosub SPI_shiftout_byte_1MSB_preclB0
    B0 = tempB2
    gosub SPI_shiftout_byte_MSB_preclB0
    high RFM22_nSEL_O
    return

; Writes a zero byte to a radio register over SPI.  (Optimised common case.)
; Register number in SPI_DATAB on call (will be destroyed); MSB is forced to 1 to enforce write mode.
; Destroys SPI_DATAB and B0.
RFM22WriteReg8Bit0:
    low RFM22_nSEL_O
    B0 = SPI_DATAB
    gosub SPI_shiftout_byte_1MSB_preclB0
    gosub SPI_shiftout_0byte_MSB_pre
    high RFM22_nSEL_O
    return


#endif





#rem
TODO: run-time health-check and reset (or panic)

See: http://www.picaxeforum.co.uk/showthread.php?23347-18M2-unreliable-at-32MHz-%28m32%29-at-3-3V&p=231717&viewfull=1#post231717

DHD20130223: Interesting thought on the RFM22 resetting itself. How would you (quickly) check in this instance if such a reset had happened so the config could be re-applied?

srnet:

There is a POR flag bit that should be set, but I found it more reliable to check if the 3 main frequency setting registers have changed away from their configured settings.

Which also serves another purpose, you can check that you are actually transmitting on the frequency you should be.

There are also circumstances where if there is enough RF power fed back into the circuit, the Si4432 (the microcontroller on the RFM22) has its brains scrambled completely, the registers go haywire. The only recovery is a shutdown of the device, so dont just ground the SDN pin, control it with a PICAXE pin so you can force a RFM22 reset.
#endrem
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
; Returns input data in B0 byte variable.
SPI_shiftin_byte_MSB_preclB0:
#ifdef REDUCE_CODE_SPACE
    gosub _SPI_sipost ; slightly less efficient, but saves a little space...
#else
    bit7 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit6 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit5 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit4 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit3 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit2 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit1 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit0 = SPI_SDI_PIN
#endif
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    return

; SPI shift in (ie read) a single byte, most-significant bit first, data post-clock.
; Returns input data in B0 byte variable.
SPI_shiftin_byte_MSB_postclB0:
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
_SPI_sipost:
    bit7 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit6 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit5 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit4 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit3 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit2 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit1 = SPI_SDI_PIN
    pulsout SPI_SCLK_O, SPI_PULSEOUT_UNITS
    bit0 = SPI_SDI_PIN
    return

; SPI shift out (ie write) a single byte, most-significant bit first with MSB forced to 1, data pre-clock.
; Sends output data from B0 byte variable.
; This 'MSB forced to 1' is useful for initiating write operations for SPI devices.
SPI_shiftout_byte_1MSB_preclB0:
    SPI_SDO_PIN = 1
    goto _SPI_shiftout_byte_1MSB_preclB

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
_SPI_shiftout_byte_1MSB_preclB:
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

; ****** diagtools.inc.bas ****** in module library
; Empty appendable PICAXE basic fragment.
; Diagnostic tools, useful for development and debugging.

#ifdef USE_MODULE_DIAGTOOLS ; Only use content if explicitly requested.


; Dump byte in B0 (not altered) as two digit hex to serial.
; B1 is destroyed.
DiagSertxdHexByte:
    B1 = B0 / 16 + "0" ; High nybble.
    gosub _DiagSertxdHexNybble
    B1 = B0 & 15 + "0" ; Low nybble.
_DiagSertxdHexNybble:
    if B1 > "9" then : B1 = B1 + 7 : endif
    sertxd(B1)
    return


#rem
Target is to be able to make a hex dump which looks like:
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

; Output dump table header of form "     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F" (note 5 leading spaces).
; B0, B1 are destroyed.
DiagHexDumpHeaderWithZeros:
    sertxd("    ");
    for B0 = 0 to 15
        sertxd(" ");
        gosub DiagSertxdHexByte
    next
    sertxd(13,10);
    return

#rem ; EXAMPLE: RFM22 register dump (omitting $7f, the RX FIFO).
gosub DiagHexDumpHeaderWithZeros
for tempB3 = 0 to $7e
    ; Insert dump line headers as necessary
    B0 = tempB3 & 15
    if B0 = 0 then
        if tempB3 != 0 then : sertxd(13,10) : endif
        B0 = tempB3 / 16
        gosub DiagSertxdHexByte
        sertxd(" :")
    endif
    SPI_DATAB = tempB3
    gosub RFM22ReadReg8Bit
    ;sertxd("Reg ",#tempB3," = ",#SPI_DATAB,13,10)
    sertxd(" ")
    B0 = SPI_DATAB
    gosub DiagSertxdHexByte
next
sertxd(13,10)
#endrem


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
    ; Nothing to see here, move along please...
#endif
