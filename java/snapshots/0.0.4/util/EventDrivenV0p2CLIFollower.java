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

package uk.org.opentrv.comms.util;

import gnu.io.SerialPort;
import gnu.io.SerialPortEvent;
import gnu.io.SerialPortEventListener;

import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;

/**Follows and prints CLI and logs output given the device filename for serial connection to CLI as args[0] and dir name as args[1].
 * Attempts to use events rather than polling for efficiency (eg long sleeps)
 * given sparse output from OpenTRV unit.
 * <p>
 * args[0] might be something like /dev/tty.usbserial-FTGACM4G
 * <p>
 * See http://playground.arduino.cc/Interfacing/Java for some RXTX info.
 * Expect to muck around with classpath and native lib path and /var/lock.
 * <p>
 * Note that FTDI USB and RXTX seems to cause hundreds--thousands of wakeups
 * which is bad from an energy-efficiency point of view.
 * (jSSC 2.8.0 seems similar on initial investigation.)
 * <p>
 * See end for release notes.
 */
public final class EventDrivenV0p2CLIFollower
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
        final File statsDir = (args.length > 1) ? new File(args[1]) : null;
        final IOHandlingV0p2 ioh = new IOHandlingV0p2();

//        if(!useRXTX)
//            {
//            final jssc.SerialPort sp = SerialSupportV0p2.openCLIPortV0p2WithJSSC(portName);
//
////            for( ; ; )
////                {
////                final byte[] text;
////                try { text = sp.readBytes(1, 1000); }
////                catch(final jssc.SerialPortTimeoutException e) { continue; }
////                if(null == text) { continue; }
////                for(final byte element : text)
////                    { ioh.processInputChar(statsDir, null, (char)(element &0xff)); }
////                }
//            sp.addEventListener(new jssc.SerialPortEventListener() {
//                @Override
//                public void serialEvent(final jssc.SerialPortEvent ev)
//                    {
//                    switch(ev.getEventType())
//                        {
//                        case jssc.SerialPortEvent.RXCHAR:
//                            {
//                            try
//                                {
//                                final byte[] text = sp.readBytes(ev.getEventValue());
//                                for(final byte element : text)
//                                    { ioh.processInputChar(statsDir, null, (char)(element &0xff)); }
//                                }
//                            catch(final Exception e)
//                                { e.printStackTrace(); }
//                            break;
//                            }
//                        }
//                    }
//                }, jssc.SerialPort.MASK_RXCHAR);
//            }
//        else
            {
            final SerialPort serialPort = SerialSupportV0p2.openCLIPortV0p2WithRXTX(portName);
            serialPort.setFlowControlMode(SerialPort.FLOWCONTROL_NONE);

            final InputStream is = serialPort.getInputStream();
            final OutputStream os = serialPort.getOutputStream();

            // Add event listener to process incoming data.
            // NOTE: DHD20140418: this causes >2000 extra wakeups per second with RXTX/SheevaPlug.
            serialPort.addEventListener(new SerialPortEventListener() {
                /**Buffer used during read()s for efficiency; never null. */
                private final byte[] buf = new byte[128];
                @Override
                public void serialEvent(final SerialPortEvent oEvent)
                    {
                    if (oEvent.getEventType() == SerialPortEvent.DATA_AVAILABLE)
                        {
                        try
                            {
                            while(is.available() > 0)
                                {
                                final int n = is.read(buf);
                                for(int i = 0; i < n; ++i)
                                    { ioh.processInputChar(statsDir, os, (char)(buf[i] &0xff)); }
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
            }

        // Wait indefinitely.
        for( ; ; ) { Thread.sleep(60_000); }
        }
    }


/*
 * RELEASE NOTES:
 *
 * 0.0.3: Slightly more efficient logging.
 *     DHD20140419: Tested against jSSC instead of RXTX.
 *     DHD20140419: Up to 1h between local temp log entries if no change, to reduce wasted effort.
 *
 * 0.0.2: Fully functional local temp logging, deployed on SheevaPlug (Ubuntu 9.04/armv5tel) and OS X (10.9.2) also with RXTX.
 */
