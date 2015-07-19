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
;symbol FHT8V_HC1 = 48 ; House code 1, constant or (byte) register.
;symbol FHT8V_HC2 = 21 ; House code 2, constant or (byte) register.
symbol FHT8V_HC1 = 13 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 73 ; House code 2, constant or (byte) register.
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
#define SUPPORT_BAKE
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


#ifdef CONFIG_DHD_BH_TESTLAB ; Testing parallel of Bo's config on DHD's desk!
; IF DEFINED: RFM23 is in use in place of RFM22.
#define RFM22_IS_ACTUALLY_RFM23 ; RFM23 used on V0.09 PCB1.
; IF DEFINED: good RF environment means that TX power level can be reduced.
#define RFM22_GOOD_RF_ENV ; Good ground-plane and antenna: drop TX level.
;#define SUPPORT_BAKE ; Simple heat/no-heat operation.
#define LOCAL_TRV ; Uses FHT8V to control district heated water flow.
#define DHW_TEMPERATURES ; Run with hot-water set-points.
#define TRV_SLEW_GLACIAL ; Minimise flow rates to minimise m^3 charges.
symbol FHT8V_HC1 = 48 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 21 ; House code 2, constant or (byte) register.
;#define USE_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
#define OMIT_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
; IF DEFINED: produce regular status reports on sertxd.
#define SERTXD_STATUS_REPORTS
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: trickle-charge supercap attached to Vcc2
#define DS1306RTC_8K1D_TRICKLE_CHARGE
; IF DEFINED: support one on and one off time per day (possibly in conjunction with 'learn' button).
#define SUPPORT_SINGLETON_SCHEDULE
symbol DEFAULT_SINGLETON_SCHEDULE_ON = 6 ; 6am on
symbol DEFAULT_SINGLETON_SCHEDULE_OFF = 20 ; 8pm off
#endif


#ifdef CONFIG_BO_DHW
; IF DEFINED: RFM23 is in use in place of RFM22.
#define RFM22_IS_ACTUALLY_RFM23 ; RFM23 used on V0.09 PCB1.
; IF DEFINED: good RF environment means that TX power level can be reduced.
#define RFM22_GOOD_RF_ENV ; Good ground-plane and antenna: drop TX level.
;#define SUPPORT_BAKE ; Simple heat/no-heat operation.
#define LOCAL_TRV ; Uses FHT8V to control district heated water flow.
#define DHW_TEMPERATURES ; Run with hot-water set-points.
#define TRV_SLEW_GLACIAL ; Minimise flow rates to minimise m^3 charges.
symbol FHT8V_HC1 = 40 ; House code 1, constant or (byte) register.
symbol FHT8V_HC2 = 00 ; House code 2, constant or (byte) register.
;#define USE_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
#define OMIT_MODULE_LDROCCUPANCYDETECTION ; LDR 'occupancy' sensing irrelevant for DHW.
; IF DEFINED: produce regular status reports on sertxd.
#define SERTXD_STATUS_REPORTS
#define USE_MODULE_DS1306RTCSPISIMPLE
; IF DEFINED: trickle-charge supercap attached to Vcc2
#define DS1306RTC_8K1D_TRICKLE_CHARGE
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

symbol BAKE_UPLIFT = 5 ; Raise target by this many degrees in 'BAKE' mode (strictly positive).

; Initial setback degrees C (strictly positive).  Note that 1C setback may result in ~8% saving in UK.
symbol SETBACK = 1
; Full setback degrees C (strictly positive and significantly, ie several degrees, greater than SETBACK).
symbol SETBACK_FULL = 3
; Prolonged inactivity time deemed to indicate room really unoccupied to trigger full setback (minutes, strictly positive).
symbol SETBACK_FULL_M = 45
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
; IFF extra broadcasts are done each minute THEN this needs to be a little over 60s minimum to allow for clock skew.
; ELSE must timeout after longer than max FHT8V inter-TX period of 118.5s.
symbol BOILER_CALL_TIMEOUT_S = 250 ; Must be > 118.5s (+ fudge/skew factor) to hear each FHT8V TX.
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
#ifdef DS1306RTC_8K1D_TRICKLE_CHARGE // Trickle-charge supercap attached to Vcc2.
gosub DS1306Set8K1DTickleCharge
#endif
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
#rem
Output should look like this:

=F0%@18C;T16 36 W255 0 F255 0
=W0%@18C;T16 38 W255 0 F255 0
=W0%@18C;T16 39 W255 0 F255 0
=W0%@18C;T16 40 W16 39 F17 39
=W0%@18C;T16 41 W16 39 F17 39
=W0%@17C;T16 42 W16 39 F17 39
=W20%@17C;T16 43 W16 39 F17 39
=W20%@17C;T16 44 W16 39 F17 39
=F0%@17C;T16 45 W16 39 F17 39

'=' starts the status line and CRLF ends it.
The initial 'W' or 'F' is warm or frost mode indication.
The nn% is the target valve open percantage.
The @nnC gives the current measured room temperature in degrees C.
Thh mm is the local current 24h time in hours and minutes.
Whh mm is the scheduled on/warm time in hours and minutes, or an invalid time if none.
Fhh mm is the scheduled off/frost time in hours and minutes, or an invalid time if none.
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
symbol TRV_MIN_SLEW_PC = 7 ; Minimum slew/error distance in central range; should be larger than smallest temperature-sensor-driven step (6) to be effective.
#ifndef TRV_SLEW_GLACIAL
symbol TRV_MAX_SLEW_PC_PER_MIN = 5 ; Maximum slew rate to fully open from off when well under target; should generally be no smaller than TRV_MIN_SLEW_PC.
#else
symbol TRV_MAX_SLEW_PC_PER_MIN = 1 ; Minimal slew rate to keep flow rates as low as possible.
#endif
; Note: keeping TRV_MAX_SLEW_PC_PER_MIN small reduces noise and overshoot and surges of water
; (eg for when charged by the m^3 in district heating systems)
; and will likely work better with high-thermal-mass / slow-response systems such as UFH.
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
; DHD20130522: port back FHT8V_MIN_VALVE_PC_REALLY_OPEN.
; DHD20130522: port back FHT8VPollSyncAndTX_First()/_Next() and debugging timestamps!
; DHD20130521: port back and match UI LED adjustments from V0.2-Arduino code, eg omitting every 4th flash when in WARM.
; DHD20130521: port back new mediumPause(), bigPause() and offPause() definitions from V0.2-Arduino code.
; DHD20130312: create simple command-line interface (will "disconnect" except at boot and while button held down).
; DHD20130301: implement weekly 'descale' operation (when room not dark!).
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
