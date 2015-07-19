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
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.text.FieldPosition;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;

/**Follows and prints CLI and logs output given the device filename for serial connection to CLI as args[0] and dir name as args[1].
 * Attempts to use events rather than polling for efficiency (eg long sleeps)
 * given sparse output from OpenTRV unit.
 * <p>
 * args[0] might be something like /dev/tty.usbserial-FTGACM4G
 * <p>
 * See http://playground.arduino.cc/Interfacing/Java for some RXTX info.
 * Expect to muck around with classpath and native lib path and /var/lock.
 */
public final class EventDrivenV0p2CLIFollower
    {
    /**Start copying output from OpenTRV unit to System.out using events.
     * @param args
     * @throws IOException
     * @throws FileNotFoundException
     * @throws InterruptedException
     */
    public static void main(final String[] args) throws Exception
        {
        if(args.length < 1) { throw new IllegalArgumentException("first arg must be serial port path"); }
        final String portName = args[0];
        final File statsDir = (args.length > 1) ? new File(args[1]) : null;
//        if((null != statsDir) && !statsDir.isDirectory()) { throw new FileNotFoundException("stats dir not present"); }

        final SerialPort serialPort = SerialSupportV0p2.openCLIPortV0p2(portName);

        final InputStream is = serialPort.getInputStream();
        final OutputStream os = serialPort.getOutputStream();

        // Add event listener to process incoming data.
        serialPort.addEventListener(new SerialPortEventListener() {
            /**Output/stats line gathered so far, limited in length. */
            private final StringBuilder inputBuf = new StringBuilder();

            @Override
            public void serialEvent(final SerialPortEvent oEvent)
                {
                if (oEvent.getEventType() == SerialPortEvent.DATA_AVAILABLE)
                    {
                    try
                        {
                        while(is.available() > 0)
                            {
                            final int ic = is.read();
                            System.out.print((char) ic);

                            // Deal with CLI prompt immediately...
                            if((ic == '>') && (0 == inputBuf.length()))
                                {
                                // Exit CLI to save energy (no command queued).
                                os.write('E');
                                os.write('\n');
                                os.flush();
                                break;
                                }

                            if((ic == '\r') || (ic == '\n'))
                                {
                                // End of line; process entire line.

                                // Discard empty lines.
                                if(0 == inputBuf.length()) { continue; }

                                switch(inputBuf.charAt(0))
                                    {
                                    case '=': // Stats line.
                                        {
                                        processLocalStats(inputBuf, statsDir);
                                        break;
                                        }
                                    }

                                inputBuf.setLength(0); // Clear buffer.
                                continue;
                                }
                            // Append char if line not too long already.
                            else if(inputBuf.length() < SerialSupportV0p2.MAX_STATS_LINE_CHARS)
                                { inputBuf.append((char) ic); }
                            }
                        }
                    catch (final Exception e)
                        { System.err.println(e.toString()); }
                }
                // Ignore all the other eventTypes for now...
                }
            });
        serialPort.notifyOnDataAvailable(true);
        }

    /**Sub-directory of stats dir for recording just local temperatures from directly-attached OpenTRV unit. */
    public static final String localTempSubdir = "localtemp";

    /**Last value written; used to avoid writing duplicates. */
    private static String lastLocalStatsValueWritten;

    /**Process local stats line from OpenTRV V0p2 unit.
     * Sample output, intended to be GNUplot-friendly:
     * <pre>
2014/04/17 19:04:46Z 20.1875 =F0%@20C3;T14 32 W255 0 F255 0 W255 0 F255 0;S10 10 20 cffO
2014/04/17 19:04:47Z 20.1875 =F0%@20C3;T14 32 W255 0 F255 0 W255 0 F255 0;S10 10 20 cffO
2014/04/17 19:07:52Z 20.125 =F0%@20C2;T14 35 W255 0 F255 0 W255 0 F255 0;S10 10 20 cffO
     * </pre>
     * eg with gnuplot such as:
     * <pre>
# Plot local temperature.
#set terminal png
#set output "temp.png"
set terminal dumb
set title "Local temp"
set grid
set timefmt "%Y/%m/%d %H:%M:%SZ"
set format x "%H%M"
show timefmt
set xdata time
plot "sample.log" using 1:3 with linespoints
     * </pre>
     */
    private static void processLocalStats(final StringBuilder line, final File statsDir)
        throws IOException
        {
        if(null == statsDir) { return; } // Not recording stats.

        // Quickly extract temperature directly from initial part of status line.
        //     =F0%@19CE; ...
        // Temp in C i between '@' and ';' with the part after the C in 16ths.
        final int atPos = line.indexOf("@");
        if((-1 == atPos) || (atPos > 6)) { return; } // Obviously broken.
        final int scPos = line.indexOf(";", atPos + 1);
        if((-1 == scPos) || (scPos > 11)) { return; } // Obviously broken.

        final float temp = Integer.parseInt(line.substring(atPos+1, scPos - 2)) +
                (Integer.parseInt(line.substring(scPos-1, scPos), 16) / 16f);

        final StringBuffer sb = new StringBuffer(line.length() + 32);
        final Date now = new Date();
        dateAndTime.format(now, sb, new FieldPosition(0));
        sb.append("Z ");
        sb.append(temp);
        sb.append(' ');
        sb.append(line);

        final String lineToLog = sb.toString();
        if(lineToLog.equals(lastLocalStatsValueWritten)) { return; }
        lastLocalStatsValueWritten = lineToLog;

        final File dir = new File(statsDir, localTempSubdir);
        if(!dir.isDirectory()) { dir.mkdirs(); }
        // Append line to file of form statsDir/localtemp/YYYYMMDD.log where date is UTC.
        final File f = new File(dir, dateForFilename.format(now) + ".log");
        try(final PrintWriter pw = new PrintWriter(new FileWriter(f, true)))
            {
            pw.println(lineToLog);
            pw.flush();
            }
        }

    /**UTC date-only format for filenames. */
    private static final SimpleDateFormat dateForFilename = new SimpleDateFormat("yyyyMMdd");
    static { dateForFilename.setTimeZone(TimeZone.getTimeZone("UTC")); }

    /**UTC full time and date format. */
    private static final SimpleDateFormat dateAndTime = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");
    static { dateAndTime.setTimeZone(TimeZone.getTimeZone("UTC")); }
    }
