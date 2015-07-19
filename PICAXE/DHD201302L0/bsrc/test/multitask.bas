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

; Test of simple multi-tasking.
; 18M2 can accommodate up to 4 tasks.
; The setfreq command cannot be used in multitasking.

#picaxe 18m2

start0:
do
toggle B.1
pause 250
loop
end

start1:
do
toggle b.2
pause 500
loop
end

start2:
do
toggle b.3
pause 1000
loop
end

start3:
do
debug
pause 2000
loop
end
