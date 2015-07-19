package uk.org.opentrv.comms.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.text.FieldPosition;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;

/**Generic handling of I/O and stats from a single OpenTRV ~V0.2 connection.
 * Use an instance for each communication session.
 * <p>
 * Note thread-safe.
 */
public final class IOHandlingV0p2
    {
    /**Accumulated characters for current input line. */
    private final StringBuilder inputBuf = new StringBuilder();

    /**Process a single new input char from the OpenTRV serial connection.
     * @param statsDir  directory into which stats are saved
     * @param inputBuf  buffer in which input for a single line is gathered
     * @param os output stream back to the OpernTRV unit, else null if not available
     * @param c  new character from the OpenTRV unit
     * @throws IOException  in case of I/O problems
     */
    public void processInputChar(final File statsDir,
                                 final OutputStream os,
                                 final char c)
        throws IOException
        {
        System.out.print(c);

        // Deal with CLI prompt immediately...
        if((c == '>') && (0 == inputBuf.length()))
            {
            if(null != os)
                {
                // Exit CLI to save energy (no command queued).
                os.write('E');
                os.write('\n');
                os.flush();
                }
            return;
            }

        if((c == '\r') || (c == '\n'))
            {
            // End of line; process entire line.

            // Discard empty lines.
            if(0 == inputBuf.length()) { return; }

            switch(inputBuf.charAt(0))
                {
                case '=': // Stats line.
                    {
                    processLocalStats(inputBuf, statsDir);
                    break;
                    }
                }

            inputBuf.setLength(0); // Clear buffer.
            return;
            }
        // Append char if line not too long already.
        else if(inputBuf.length() < SerialSupportV0p2.MAX_STATS_LINE_CHARS)
            { inputBuf.append(c); }
        }

    /**Touch the specified file, creating if necessary. */
    private static final void touch(final File f) throws IOException
        {
        if(!f.exists())
            { new FileOutputStream(f, true).close(); }
        else
            { f.setLastModified(System.currentTimeMillis()); }
        }

    /**Sub-directory of stats dir for recording just local temperatures from directly-attached OpenTRV unit. */
    public static final String localTempSubdir = "localtemp";

//    /**Last value written; used to avoid writing complete duplicates. */
//    private static String lastLocalStatsValueWritten;

    /**Last temperature written (as parsed raw from the status string) to save some duplicate writes. */
    private static String lastRawTempValueWritten;

    /**Minimum interval in seconds between local temperature stats entries unless the temp changes; strictly positive.
     * This is to minimise potentially futile disc traffic.
     * <p>
     * A value of less than one minute is likely to be equivalent to disabling this.
     * <p>
     * There is likely to be limited value in increasing this beyond 1h;
     * the longest typical runs without temperature change will be ~20m.
     */
    private static final int MIN_LT_WRITE_INTERVAL_UNCHANGED_MS = 3600_000; // 1h

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
     * <p>
     * Writes to a different file (of the form localtemp/YYYYMMDD.log) for each day,
     * appending each new record as it is made.
     * <p>
     * Also attempts to 'touch' updated.flag in the directory containing the log file
     * as a trigger for makefiles and similar.
     * <p>
     * This will limit updates to one every few minutes unless the temperature changes.
     * <p>
     * Intended to be called at most about once per minute.
     * <p>
     * Not thread-safe.
     */
    private void processLocalStats(final StringBuilder line, final File statsDir)
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

        final Date now = new Date();
        final File dir = new File(statsDir, localTempSubdir);
        final File logFile = new File(dir, dateForFilename.format(now) + ".log");

        // Extract local temperature from stats line.
        final String rawTempValue = line.substring(atPos+1, scPos);
        final int rtlen = rawTempValue.length();
        final float temp = Integer.parseInt(rawTempValue.substring(0, rtlen-2), 10) +
                (Integer.parseInt(rawTempValue.substring(rtlen-1), 16) / 16f);

        // If the temperature hasn't changed since the last call
        // then avoid logging if the log was recently updated
        // so save some unnecessary processing and file traffic.
        if(rawTempValue.equals(lastRawTempValueWritten))
            {
            final long lastWrite = logFile.lastModified();
            if((0 != lastWrite) && ((now.getTime() - lastWrite) < MIN_LT_WRITE_INTERVAL_UNCHANGED_MS))
                { return; }
            }

        // Create the full log line.
        final StringBuffer sb = new StringBuffer(line.length() + 32);
        dateAndTime.format(now, sb, new FieldPosition(0));
        sb.append("Z ");
        sb.append(temp);
        sb.append(' ');
        sb.append(line);
        final String lineToLog = sb.toString();

//        // Avoid ever writing a completely duplicate line to the log.
//        if(lineToLog.equals(lastLocalStatsValueWritten)) { return; }

        if(!dir.isDirectory()) { dir.mkdirs(); }
        // Append line to file of form statsDir/localtemp/YYYYMMDD.log where date is UTC.
        try(final PrintWriter pw = new PrintWriter(new FileWriter(logFile, true)))
            {
            pw.println(lineToLog);
            pw.flush();
            }
        final File updatedFlag = new File(dir, "updated.flag");
        touch(updatedFlag);
//        lastLocalStatsValueWritten = lineToLog;
        lastRawTempValueWritten = rawTempValue;
        }

    /**UTC date-only format for filenames; not thread-safe. */
    private  final SimpleDateFormat dateForFilename = new SimpleDateFormat("yyyyMMdd");
    { dateForFilename.setTimeZone(TimeZone.getTimeZone("UTC")); }

    /**UTC full time and date format; not thread-safe. */
    private final SimpleDateFormat dateAndTime = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");
    { dateAndTime.setTimeZone(TimeZone.getTimeZone("UTC")); }
    }
