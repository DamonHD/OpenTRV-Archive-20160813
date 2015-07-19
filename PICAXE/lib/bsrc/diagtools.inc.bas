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