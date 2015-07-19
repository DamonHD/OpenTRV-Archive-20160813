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

; Simple assessment of system speed at different clock frequencies.
; Note that for the 18M2/18M2+, both 4MHz (default) and 16MHz preserve elapsed-time measurement with 'time'.

#picaxe 18m2

do
    setfreq m4
    gosub timeit
    w0 = w8 ; 4MHz result in w0, 549 @ 2013/01/22 on 18M2+, thus maybe ~600us/command.
    setfreq m16
    gosub timeit
    w1 = w8 ; 16MHz result in w1, 2196 @ 2013/01/22 on 18M2+, thus maybe ~150us/command.
    debug
loop



; Run a timing cycle; loops per second left in w8.  (Destroys w9)
; Wait until 'time' just ticks over,
; then run a tight timing loop, counting, until 'time' ticks over again.
timeit:
    w8 = 0
    w9 = time
    do loop until time != w9
    ; performance measure
    w9 = time
    do inc w8 loop until time != w9
    return