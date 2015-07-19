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
;#define CONFIG_DHD_STUDY
#define CONFIG_DHD_KITCHEN
;#define CONFIG_DHD_LIVINGROOM
;#define CONFIG_DHD_BEDROOM1
;#define CONFIG_DHD_TESTLAB
;#define CONFIG_DHD_BH_TESTLAB ; Testing Bo's configuration, remotely, with supercap.
;#define CONFIG_BH_DHW ; Bo's hot water.

