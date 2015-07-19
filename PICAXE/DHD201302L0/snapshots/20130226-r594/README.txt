First version with boiler being remotely controlled over wireless (868MHz, via RFM22B modules)
from thermostat/rad node to boiler node (just TestFHT8VBoilerNode.bas in this case).
If *any* thermostat/rad node calls for heat then the boiler will be switched on.

With this, soft zoning is possible!