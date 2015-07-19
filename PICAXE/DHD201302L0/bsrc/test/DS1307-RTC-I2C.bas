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

; Test access to DS1307 RTC using I2C from 18M2+.
; For 18M2+ on AXE091 ***with 5V regulated supply***.
; CODE MAINLY DERIVED FROM PICAXE.COM EXAMPLES...

; Also tests accuracy of 18M2+ notion of elapsed time in the absence of sleep/nap/etc @4MHz.
; DHD20130128: on my system elapsed time differs from real time by a little under 1%.

; I2C SCL to B.4 (p10 on 18M2+)
; I2C SDA to B.1 (p7 on 18M2+)

#picaxe 18M2

symbol seconds = b0
symbol mins = b1
symbol hour = b2
symbol day = b3
symbol date = b4
symbol month = b5
symbol year = b6
symbol control = b7

		;i2cslave %11010000, i2cslow, i2cbyte				; set PICAXE as master and DS1307 slave address
		hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte				; set PICAXE as master and DS1307 slave address

; write time and date e.g. to 00:00:00 on 01/01/2013
start_clock:
		let seconds = $00						; 00 Note all BCD format
		let mins = $00							; 00 Note all BCD format
		let hour = $00							; 00 Note all BCD format
		let day = $01							; 01 Note all BCD format
		let date = $01							; 01 Note all BCD format
		let month = $01							; 01 Note all BCD format
		let year = $13							; 13 Note all BCD format
		let control = %00010000						; Enable output at 1Hz
		;writei2c 0,(seconds,mins,hour,day,date,month,year,control)
		hi2cout 0,(seconds,mins,hour,day,date,month,year,control)


		;debug



; Main loop; never exits.
do

    ; Read the clock time
	;readi2c 0,(seconds,mins,hour,day,date,month,year)
	hi2cin 0,(seconds,mins,hour,day,date,month,year)
	
	; Report time.
	; debug ; may interfere with elapsed time measurement
	b8 = seconds / 16
	b8 = b8 * 10
	b15 = seconds % 16
	b8 = b8 + b15
	b9 = mins / 16
	b9 = b9 * 10
	b15 = mins % 16
	b9 = b9 + b15
	w5 = b9 * 60
	w5 = w5 + b8
	sertxd ("elapsed time=",#time,", real=",#w5,13,10);
	
	pause 10000

loop ; end of main loop

