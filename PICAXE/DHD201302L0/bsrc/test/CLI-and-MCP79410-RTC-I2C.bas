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

; Test of general CLI principles and interaction with MCP79140 RTC using I2C from 18M2+.
; For 18M2+ on AXE091 ***with 5V regulated supply***.

; Accept lines of form:
;   * (set Time) "T HH MM" to set the time to HH:MM in 24h clock mode.
;   * (Exit shell / multi-line CLI) "E"
;   * (Learn / Forget simple schedule) "L" / "F"
;   * (show Status) "S"
;   * (set simple single Program) "P ON OF" to switch on at ON:00 and off at OF:00.
;   * (set simple Repeat) "R" cancels any program if currently in frost mode, else comes on for an hour every 24h from now.
;
; For FHT8V systems this may also support:
;   * (set FHT8V house codes each 0--99) "F H1 H2" where H1 and H2 are the two house-code components.


symbol startWaitSec = 20 ; Number of seconds to wait at start-up for CLI command.
symbol CLIPromptChar = "*" ; Character that should trigger/prompt pending command from user side.

; I2C SCL to B.4 (p10 on 18M2+)
; I2C SDA to B.1 (p7 on 18M2+)

#picaxe 18M2

hi2csetup i2cmaster, %11011110, i2cfast, i2cbyte ; Set PICAXE as master and MCP79140 slave.  (Can be fast/400KHz where V+ > 2.5V.)

gosub SertxdReportTime

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

; Enable 1Hz output on MFP.
hi2cout 7,($40)


; Wait a limited time for CLI input at start-up.
for B4 = startWaitSec to 1 step -1
    sertxd("Start in ",#B4,"s, now ");
    gosub SertxdDumpTimeHHMM
    sertxd(", drop into CLI with any char...", 13,10);
    SERRXD [1000,warmuptimeout], B0
    gosub CLIShell
    exit ; User has finished with CLI.
    warmuptimeout: ; No chars from user (yet) so stop...
next B4


; Main loop; never exits.
reconnect
do

    ; Read the clock time
    hi2cin 0,(B0,B1,B2,B3,B4,B5,B6,B7) ; ss, mm, hh, weekday + ctrl, dd, mm, yy, control reg

    gosub SertxdReportTime

    ; Long energy-saving sleep...
    sleep 1

    ; Quick poll.
    W0 = 500
    gosub CLIPoll
    reconnect

loop ; end of main loop

; Return time on complete line ending CRLF.
SertxdReportTime:
    sertxd("Time: ");
    gosub SertxdDumpTimeHHMM
    sertxd(13,10)
    return

; Dump (to sertxd) current 24h time as HH MM
; B0, B1, B2 destroyed
SertxdDumpTimeHHMM:
    hi2cin 1,(B2,B0)
    gosub SertxdBCDByte
    sertxd(" ")
    B0 = B2
    gosub SertxdBCDByte
    return

; Dump (to sertxd) byte in B0 (not altered) as two digit hex/BCD to serial.
; B1 is destroyed.
SertxdBCDByte:
    B1 = B0 / 16 + "0" ; High nybble.
    gosub _SertxdBCDNybble
    B1 = B0 & 15 + "0" ; Low nybble.
_SertxdBCDNybble:
    sertxd(B1)
    return

; Multi-line CLI shell (has to be explicitly "E"xited, though will eventually time out).
; Trailing CLIPromptChar is cue to automated interface to send command.
; B0, B1, B2, B3, B4 destroyed.
; Does NOT reconnect.
CLIShell:
    sertxd("CLI (Exit, Status, T HH MM, Learn, Forget)", 13,10, CLIPromptChar)
    SERRXD [60000,_CLIShellTimeout], B0 ; If no response for a long time, exit and allow to reconnect.
    gosub CLIShellInner ; Handle response.
    goto CLIshell ; Get next command...
_CLIShellTimeout:
    return

; CLI one-shot poll (waits briefly for response to CLIPromptChar, for approx milliseconds in W0).
; B0, B1, B2, B3, B4 destroyed.
; Does NOT reconnect.
CLIPoll:
    sertxd(CLIPromptChar)
    SERRXD [W0,_CLIPollTimeout], B0 ; If no response for a long time, exit and allow to reconnect.
    gosub CLIShellInner ; Handle response.
_CLIPollTimeout:
    return

; Handle (non-timeout) result of polling for CLI input with first byte in B0.
; B0, B1, B2, B3, B4 destroyed.
; Caller should send CLIPromptChar, poll for input, call this if no timeout, and reconnect if required.
CLIShellInner:
    select case B0
        case "T" ; Set time HH MM (24hr clock, local time)
            SERRXD [100, CLIshell], #B0, #B1 ; Read in-flight HH and MM...
            if B0 > 23 OR B1 > 59 then
                gosub _CLIShellErr
            else
                B4 = B0 % 10
                B2 = B0 / 10 * 16 + B4 ; B2 is now BCD hours
                B4 = B1 % 10
                B3 = B1 / 10 * 16 + B4 ; B3 is now BCD minutes
                hi2cout 1,(B3,B2) ; Set RTC.  (Should maybe stop and restart clock...)
                gosub SertxdReportTime ; Report time just set.
            endif

        case "L" ; Learn current time to repeat.
            ; TODO

        case "F" ; Forget/cancel simple schedule.
            ; TODO

        case "S" ; Status
            sertxd("@") ; Indicate status response...
            gosub SertxdReportTime

        case "E" ; EXIT
            gosub CLIEatEOL
            return

        else ; BAD COMMAND
            gosub _CLIShellErr

    endselect
    gosub CLIEatEOL ; Clean up...
    return

; Indicate an error.
_CLIShellErr:
    sertxd("?", 13,10)
    return

; Spend a little time trying to eat characters up until any LF if still coming at us...
CLIEatEOL:
    SERRXD [100, _CLIEatEOLNoChar], B0
    if B0 != 10 then goto CLIEatEOL
_CLIEatEOLNoChar: ; No char waiting... (or at EOL)
    return