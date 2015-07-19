/*
The OpenTRV project licenses this file to you
under the Apache Licence, Version 2.0 (the "Licence");
you may not use this file except in compliance
with the Licence. You may obtain a copy of the Licence at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the Licence is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the Licence for the
specific language governing permissions and limitations
under the Licence.

Author(s) / Copyright (s): Damon Hart-Davis 2014
*/

package uk.org.opentrv.test.hw;

import gnu.io.SerialPort;
import gnu.io.SerialPortEvent;
import gnu.io.SerialPortEventListener;

import java.io.InputStream;
import java.io.OutputStream;

import uk.org.opentrv.comms.util.SerialSupportV0p2;

/**Used to help verify the primary board timing accuracy for a REV7 board.
 * Expects a 2s 'tick' delivered as a '*' character over serial
 * based on a 2s basic cycle and altMain code on the board that looks like this:
<pre>
// Version of loopAlt() used to verify 32768Hz xtal clock speed.
// Outputs a '*' every 2s.
// Avoids wakeup from sleep and (eg) RTC interrupt to minimise jitter.
void loopAlt()
  {
  const uint8_t magicTick = 0x3f;
  // Wait until magic tick has passed if not already done so.
  while(magicTick == getSubCycleTime()) { }
  // Wait until magic tick some time after start of underlying 2s cycle.
  while(magicTick != getSubCycleTime()) { }
  // Signal to host ASAP with minimum jitter.
  DEBUG_SERIAL_PRINT_FLASHSTRING("*");
  }
</pre>
 * <p>
 * Aiming for max ~1 minute per month (~15 mins per year) error: ~20ppm.
 * <p>
 * The frequency is being checked relative to the clock of the system running this Java code,
 * which ideally should be NTP- (or similarly-) disciplined.
 * <p>
 * Fragment of output from run against REV2 board 20150204:
<pre>
this tick ns: 1998874000
expected vs actual total ns: 9084000000000 vs 9084334455000
ppm error: 36
this tick ns: 2015156000
expected vs actual total ns: 9086000000000 vs 9086349611000
ppm error: 38
this tick ns: 1998801000
expected vs actual total ns: 9088000000000 vs 9088348412000
ppm error: 38
</pre>
 */
public final class TimingVerifierOverSerial
    {
    /**Use RXTX for serial I/O. */
    public static final boolean useRXTX = true;

    /**Start copying output from OpenTRV unit to System.out using events.
     * @param args
     */
    public static void main(final String[] args) throws Exception
        {
        if(args.length < 1) { throw new IllegalArgumentException("first arg must be serial port path"); }
        final String portName = args[0];

        final SerialPort serialPort = SerialSupportV0p2.openCLIPortV0p2WithRXTX(portName);
        serialPort.setFlowControlMode(SerialPort.FLOWCONTROL_NONE);

        final InputStream is = serialPort.getInputStream();
        final OutputStream os = serialPort.getOutputStream();

        // Add event listener to process incoming data.
        serialPort.addEventListener(new SerialPortEventListener() {
            /**Set to true once the time sequence has started. */
            private boolean started;
            /**Timestamp of first tick in error-free run. */
            private long firstTick;
            /**Tick (interval) count in error-free run. */
            private int tickCount;
            /**Timestamp of last tick. */
            private long lastTick;
            /**Minimal receive buffer.*/
            final byte[] buf = new byte[1];
            @Override
            public void serialEvent(final SerialPortEvent oEvent)
                {
                if(oEvent.getEventType() == SerialPortEvent.DATA_AVAILABLE)
                    {
                    try
                        {
                        while(is.available() > 0)
                            {
                            final int n = is.read(buf);
                            if(1 != n) { continue; }
                            if(!started)
                                {
                                if('*' != buf[0]) { continue; }
                                started = true;
                                firstTick = lastTick = System.nanoTime();
                                tickCount = 0;
                                continue;
                                }

                            // Force restart of calculations in case of unexpected char received.
                            if('*' != buf[0]) { System.err.print((char) buf[0]); started = false; continue; }

                            final long thisTick = System.nanoTime();
                            final long tickMs = thisTick - lastTick;
                            lastTick = thisTick;
                            System.out.println("this tick ns: " + tickMs);
                            if((tickMs < 1_800_000_000L) || (tickMs > 2_200_000_000L)) { System.err.println("resync needed"); started = false; continue; }
                            ++tickCount;
                            final long expectedTotalNs = 2_000_000_000L * tickCount;
                            final long actualTotalNs = thisTick - firstTick;
                            System.out.println("expected vs actual total ns: " + expectedTotalNs + " vs " + actualTotalNs);
                            final long ppmError = (Math.abs(expectedTotalNs - actualTotalNs) * 1_000_000) / expectedTotalNs;
                            System.out.println("ppm error: " + ppmError);
                            }
                        }
                    catch (final Exception e)
                        { System.err.println(e.toString()); }
                    }
                // Ignore all the other eventTypes for now...
                }
            });
        serialPort.notifyOnDataAvailable(true);

//        // Block waiting for I/O from the serial port.
//        // This can be moved to another thread if need be.
//        // Under some circumstances this could cause fewer idle wakeups.
//        int ic;
//        while(-1 != (ic = is.read()))
//            { processInputChar(statsDir, inputBuf, os, (char)ic); }

        // Wait indefinitely.
        for( ; ; ) { Thread.sleep(60_000); }
        }
    }


/*
 * RELEASE NOTES:
 */
