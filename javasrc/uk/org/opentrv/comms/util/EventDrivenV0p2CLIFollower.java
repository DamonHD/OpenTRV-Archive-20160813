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

import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsString;
import static uk.org.opentrv.comms.cfg.ConfigUtil.loadConfigFile;
import gnu.io.SerialPort;
import gnu.io.SerialPortEvent;
import gnu.io.SerialPortEventListener;

import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import uk.org.opentrv.comms.cfg.ConfigException;
import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsHandlerFactory;
import uk.org.opentrv.comms.statshandlers.filter.AsyncStatsHandlerWrapper;

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

    public static final File DEFAULT_CONFIG_FILE = new File(System.getProperty("user.home"), "config.json");

    /**Append magic 'DHD' handlers to the (non-null) list provided. */
    /*public static void addDHDHandlers(final List<StatsHandler> handlers, final File edxFile)
        {
        // Sets up some simple hardwired fanout to Twitter, EDX, etc.
        // FIXME: abolish this and replace with sensible XML (etc) config or Apache Camel, etc!
        // Twitter raw channels from external RE-powered sensors.
        handlers.add(new SingleTwitterChannelTemperature(new SingleTwitterChannelConfig("b39a")));
        handlers.add(new SingleTwitterChannelTemperature(new SingleTwitterChannelConfig("819c")));
        // EDX windowed-log channel from all external sensors.
        final Set<String> allowedIDs = new HashSet<>();
        allowedIDs.add("b39a");
        allowedIDs.add("819c");
        final RecentStatsWindowFileWriter edxc = new RecentStatsWindowFileWriter(edxFile);
        final SimpleStaticFilterStatsHandlerWrapper extFilter = new SimpleStaticFilterStatsHandlerWrapper(edxc, allowedIDs);
        handlers.add(extFilter);
        // Set up simple OEM feed from JSON stats if credentials are present (else ignore).
        try
            {
            final OpenEnergyMonitorPostCredentials credsOEM1 = OpenEnergyMonitorPostCredentials.getEmoncmsCrentials("emonserver1");
            final String hexID = "8196";
            final Map<String, String> mapping = new HashMap<>();
            mapping.put("T|C16", "Temp16");
            mapping.put("B|cV", "BattcV");
            mapping.put("L", "L");
            final OpenEnergyMonitorPostConfig configOEM1 = new OpenEnergyMonitorPostConfig(
                credsOEM1,
                "819c",
                '{',
                mapping,
                "819c");
            handlers.add(new OpenEnergyMonitorPostSimple(configOEM1));
            }
        catch(final IOException e)
            {
            e.printStackTrace();
            // Fall through and ignore OEM feed.
            }
        }*/

    /**Start copying output from OpenTRV unit to System.out using events.
     * @param args  [0] is optional config file name
     */
    public static void main(final String[] args) throws Exception
        {
        final File configFile = (args.length >= 1) ? new File(args[0]) : DEFAULT_CONFIG_FILE;
        System.err.println("Loading config from "+configFile.getCanonicalPath());
        final Map<?,?> config = loadConfigFile(configFile);
        final String portName = getAsString(config, "serialPort");
        if(null == portName) { throw new ConfigException("Port name not found in config"); }
        //if(args.length < 1) { throw new IllegalArgumentException("first arg must be serial port path"); }
        //final String portName = args[0];
        final List<StatsHandler> handlers = StatsHandlerFactory.getInstance().newHandlerList(config);
        /*final List<StatsHandler> handlers = new ArrayList<StatsHandler>();
        if((args.length >= 2) && ("-dhd".equals(args[1])))
            {
            System.err.println("Adding hard-wired 'DHD' handler set...");
            handlers.add(new SimpleFileLoggingStatsHandler((args.length > 2) ? args[2] : "out_test/stats"));
            addDHDHandlers(handlers, new File((args.length > 3) ? args[3] : "out_test/edx.json"));
            }
        else
            {
            if(args.length > 1)
                {
                handlers.add(new SimpleFileLoggingStatsHandler(args[1]));
                }
            if(args.length > 2)
                {
                try { handlers.add(new RkdapHandler(args[2])); }
                catch(final MalformedURLException muex)
                    { System.out.println("Malformed URL "+args[2]+", ignoring RKDAP handler"); }
                }
            }*/
        final IOHandlingV0p2 ioh = new IOHandlingV0p2();

        final List<StatsHandler> wrappedHandlers = new ArrayList<>(handlers.size());
        for(final StatsHandler sh : handlers) { wrappedHandlers.add(new AsyncStatsHandlerWrapper(sh)); }

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
                                    { ioh.processInputChar(wrappedHandlers, os, (char)(buf[i] & 0xff)); }
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
 * 0.0.6: 20141123: added handling of JSON (text) format stats frames see TODO-389
 *
 * 0.0.5: 20140517: more even-handed treatment of all remote stats (including dir rename)
 *
 * 0.0.4: 20140422: remoteTemp logging of remote-node temperature
 *
 * 0.0.3: Slightly more efficient logging.
 *     DHD20140419: Tested against jSSC instead of RXTX.
 *     DHD20140419: Up to 1h between local temp log entries if no change, to reduce wasted effort.
 *
 * 0.0.2: Fully functional local temp logging, deployed on SheevaPlug (Ubuntu 9.04/armv5tel) and OS X (10.9.2) also with RXTX.
 */
