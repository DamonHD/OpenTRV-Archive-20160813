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

Author(s) / Copyright (s): Bruno Girin 2014
                           Damon Hart-Davis 2014--2015
*/

package uk.org.opentrv.comms.statshandlers.builtin;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.text.FieldPosition;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;

import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.support.Util;
import uk.org.opentrv.comms.util.CommonSensorLabels;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

/**Logs stats in a simple and efficient way. */
public class SimpleFileLoggingStatsHandler implements StatsHandler
    {
    /**Stats top directory to use; never null. */
    private final File statsDir;

    public SimpleFileLoggingStatsHandler(final String statsDirName)
        {
        if(null == statsDirName) { throw new IllegalArgumentException(); }
        this.statsDir = new File(statsDirName);
        }

    /**Filename for flag touched each time that the latest (decoded binary) log file is.
     * Some implementations may have this as a symlink to the latest log file instead,
     * to get the update timestamp for free with less disc traffic.
     */
    public static final String UPDATED_FLAG_FILENAME = "updated.flag";

    /**Filename for flag touched each time that the latest JSON log file is.
     * Some implementations may have this as a symlink to the latest JSON log file instead,
     * to get the update timestamp for free with less disc traffic.
     */
    public static final String UPDATED_JSON_FLAG_FILENAME = "updated.JSON.flag";

    /**Sub-directory of stats dir for recording just local temperatures from directly-attached OpenTRV unit. */
    public static final String localTempSubdir = "localtemp";

    /**Last temperature written (as parsed raw from the status string) to save some duplicate writes. */
    private String lastRawTempValueWritten;

    /**Minimum interval in milliseconds between temperature stats (for a given sensor) entries unless the temp changes; strictly positive.
     * This is to minimise potentially futile disc traffic
     * and other downstream work.
     * <p>
     * A value of less than one minute is likely to be equivalent to disabling this.
     * <p>
     * There is likely to be limited value in increasing this beyond 1h;
     * the longest typical runs without temperature change will be ~20m.
     */
    private static final int MIN_TEMP_LOG_WRITE_INTERVAL_UNCHANGED_MS = 3600_000; // 1h

    /**Process local stats line/message from OpenTRV V0p2 unit.
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
    public void processLocalStats(final String message, final long timestamp) throws IOException {
        // Quickly extract temperature directly from initial part of status line.
        //     =F0%@19CE; ...
        // Temp in C i between '@' and ';' with the part after the C in 16ths.
        // Reject obviously-broken records.
        final int atPos = message.indexOf('@');
        if((-1 == atPos) || (atPos > 6)) { return; } // Obviously broken.
        final int scPos = message.indexOf(';', atPos + 1);
        if((-1 == scPos) || (scPos > 11)) { return; } // Obviously broken.

        final Date now = new Date(timestamp); // new Date();
        final File dir = new File(statsDir, localTempSubdir);
        final File logFile;
        synchronized(dateForFilename) { logFile = new File(dir, dateForFilename.format(now) + ".log"); }

        // Extract local temperature from stats line.
        final String rawTempValue = message.substring(atPos+1, scPos);
        final float temp = ParsedRemoteBinaryStatsRecord.parseTemperatureFromDDCH(rawTempValue);

        // If the temperature hasn't changed since the last call
        // then avoid logging if the log was recently updated
        // so save some unnecessary processing and file traffic.
        if(rawTempValue.equals(lastRawTempValueWritten))
            {
            final long lastWrite = logFile.lastModified();
            if((0 != lastWrite) && ((now.getTime() - lastWrite) < MIN_TEMP_LOG_WRITE_INTERVAL_UNCHANGED_MS))
                { return; }
            }

        // Create the full log line.
        final StringBuffer sb = new StringBuffer(message.length() + 32);
        synchronized(dateAndTime) { dateAndTime.format(now, sb, new FieldPosition(0)); }
        sb.append("Z ");
        sb.append(temp);
        sb.append(' ');
        sb.append(message);
        final String lineToLog = sb.toString();

        if(!dir.isDirectory()) { dir.mkdirs(); }
        // Append line to file of form statsDir/localtemp/YYYYMMDD.log where date is UTC.
        try(final PrintWriter pw = new PrintWriter(new FileWriter(logFile, true)))
            {
            pw.println(lineToLog);
            pw.flush();
            }
        final File updatedFlag = new File(dir, UPDATED_FLAG_FILENAME);
        Util.touch(updatedFlag);
        lastRawTempValueWritten = rawTempValue;
    }

    /**Wrap inbound leaf JSON with timestamp and concentrator ID and retain as single line JSON array.
     * Time will be written out as UTC in unambiguous ISO-8601 UTC showing the 'Z' timezone;
     * time resolution is one second.
     * <p>
     * Neither the concentratorID nor the rawJSON may contain any non-printable non-ASCII characters,
     * in particular no CR nor LF (the acceptable range is [32,126])
     * and the concentrator ID should be pure alphanumeric (eg not contain spaces),
     * with the time first on the line and the concentratorID second,
     * so that the result is directly suitable to write in a line-formated text log,
     * and to at least preprocess with (for example) line-oriented *nx tools.
     * <p>
     * @see http://www.earth.org.uk/OpenTRV-protocol-discussions-201411-1.html
     * <p>
     * TODO: optimise; written for simplicity and correctness initially.
     *
     * @param timeUTC  UTC time
     * @param concentratorID  alphanumeric ASCII7 unique concentrator ID or empty if none; valid chars [0-9A-Za-z]
     * @param rawJSON  short printable-ASCII7 valid JSON (usually object {...}) text from leaf node; non-empty, all chars [32,126]
     * @return single-line three-element printable JSON array of
     *     [ "UTC-ISO8601-timestamp", "concentratorID", {leaf raw JSON object} ]
     *     with spaces around fields (but not before each comma separator)
     *     to simplify processing by dumber line-oriented tools at the cost of a little redundancy
     */
    public static String wrapLeafJSONAsArrayLogLine(final long timeUTC, final String concentratorID, final String rawJSON)
        {
        // Validate arguments quickly.
        if(null == concentratorID) { throw new IllegalArgumentException(); }
        if((null == rawJSON) || rawJSON.isEmpty()) { throw new IllegalArgumentException(); }
        for(final char c : concentratorID.toCharArray()) { if((c < 32) || (c > 126) || !Character.isLetterOrDigit(c)) { throw new IllegalArgumentException("bad char "+(int)c); } }
        for(final char c : rawJSON.toCharArray()) { if((c < 32) || (c > 126)) { throw new IllegalArgumentException(); } }
        final JSONParser parser = new JSONParser();
        // Reject invalid raw JSON.
        try { parser.parse(rawJSON); } catch(final ParseException e) { throw new IllegalArgumentException(e); }

        // Create the full log line as JSON array of time, concentrator ID, raw JSON object.
        final StringBuffer sb = new StringBuffer();
        sb.append("[");
        sb.append(' ');

        sb.append('"');
        final Date now = new Date(timeUTC);
        Util.appendISODateTime(sb, now);
//        synchronized(dateAndTimeISO8601) { dateAndTimeISO8601.format(now, sb, new FieldPosition(0)); }
        sb.append('"');
        sb.append(", ");

        sb.append('"');
        sb.append(concentratorID);
        sb.append('"');
        sb.append(", ");

        sb.append(rawJSON);

        sb.append(' ');
        sb.append(']');
        return(sb.toString());
        }

    /**Sub-directory of stats dir for recording remote stats (esp temperatures) from directly-attached OpenTRV unit. */
    public static final String remoteStatsSubdir = "remote";

    /**Map from ID to last remote record written for that ID, including time; non-null. */
    private final Map<String, ParsedRemoteBinaryStatsRecord> lastWrittenByID = new HashMap<>();

    /**Process remote stats message from OpenTRV V0p2 unit.
     * This is intended to process the printable-ASCII form of remote binary stats lines starting with '@', eg:
     * <pre>
@D49;T19C7
@2D1A;T20C7
@A45;P;T21CC
@3015;T25C8;L62;O1
     * </pre>
     * and remote JSON stats lines starting with '{', eg:
<pre>
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":88,"L":229,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":227,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":229,"B|cV":256}
</pre>
     * <p>
     * Although this separates out temperature for easiest direct processing
     * for binary ('@') records where it is known to be present,
     * this writes a new log line when any (significant) stat/parameter changes,
     * so should serve as a reasonable database for all parameters.
     * <p>
     * This forces out a log line periodically even in the absence of parameter change.
     * <p>
     * Not thread-safe.
     */
    public void processRemoteStats(final String message, final long timestamp) throws IOException
        {
        final char firstChar = message.charAt(0);
        if('{' == firstChar)
            {
            // Process potential JSON; reject if bad.
            final long nowms = timestamp; // System.currentTimeMillis();
            final String lineToLog = wrapLeafJSONAsArrayLogLine(nowms, "", message);
            // Prepare to write to the log file...
            final Date now = new Date(nowms);
            final File dir = new File(statsDir, remoteStatsSubdir);
            final File logFile;
            synchronized(dateForFilename) { logFile = new File(dir, dateForFilename.format(now) + ".json"); }
            if(!dir.isDirectory()) { dir.mkdirs(); }
            // Append line to file of form statsDir/remote/YYYYMMDD.json where date is UTC.
            try(final PrintWriter pw = new PrintWriter(new FileWriter(logFile, true)))
                {
                pw.println(lineToLog);
                pw.flush();
                }
            final File updatedFlag = new File(dir, UPDATED_JSON_FLAG_FILENAME);
            Util.touch(updatedFlag);
            return;
            }

        // Ignore all but binary/'@' format beyond here.
        if(CommonSensorLabels.ID.getLabel() != firstChar) { return; }

        final ParsedRemoteBinaryStatsRecord parsed = new ParsedRemoteBinaryStatsRecord(message);
        if("".equals(parsed.ID)) { return; } // Skip record with no ID.

        // Avoid writing duplicate entries for any one node/ID within specified minimum interval.
        // Write new log entry on change of any data item (possibly excluding any time field).
        // TODO: consider forcing the first entry for each new log file.
        final ParsedRemoteBinaryStatsRecord lw = lastWrittenByID.get(parsed.ID);
        if((null != lw) &&
           message.equals(lw.raw) &&
           ((parsed.constructionTime - lw.constructionTime) < MIN_TEMP_LOG_WRITE_INTERVAL_UNCHANGED_MS))
            { return; } // Reject duplicate.

        final Date now = new Date(parsed.constructionTime);

        // Create the full log line.
        final StringBuffer sb = new StringBuffer(message.length() + 32);
        synchronized(dateAndTime) { dateAndTime.format(now, sb, new FieldPosition(0)); }
        sb.append("Z ");
        sb.append(parsed.ID);
        sb.append(' ');
        sb.append(parsed.getTemperature());
        sb.append(' ');
        sb.append(message);
        final String lineToLog = sb.toString();

        final File dir = new File(statsDir, remoteStatsSubdir);
        final File logFile;
        synchronized(dateForFilename) { logFile = new File(dir, dateForFilename.format(now) + ".log"); }
        if(!dir.isDirectory()) { dir.mkdirs(); }
        // Append line to file of form statsDir/remote/YYYYMMDD.log where date is UTC.
        try(final PrintWriter pw = new PrintWriter(new FileWriter(logFile, true)))
            {
            pw.println(lineToLog);
            pw.flush();
            }
        final File updatedFlag = new File(dir, UPDATED_FLAG_FILENAME);
        Util.touch(updatedFlag);
        lastWrittenByID.put(parsed.ID, parsed);
        }

    /**UTC date-only format for filenames; hold lock on this instance while using for thread-safety. */
    private static final SimpleDateFormat dateForFilename = new SimpleDateFormat("yyyyMMdd");
    { dateForFilename.setTimeZone(TimeZone.getTimeZone("UTC")); }

    /**UTC full date and time format; hold lock on this instance while using for thread-safety. */
    private static final SimpleDateFormat dateAndTime = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");
    { dateAndTime.setTimeZone(TimeZone.getTimeZone("UTC")); }
//
//    /**ISO-8601 UTC full date and time format with Z (eg 2011-12-03T10:15:30Z); hold lock on this instance while using for thread-safety. */
//    private static final SimpleDateFormat dateAndTimeISO8601 = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
//    { dateAndTimeISO8601.setTimeZone(TimeZone.getTimeZone("UTC")); }

    /**Accept all message times and route to internal handler as appropriate.
     * Ignore authentication for now.
     */
    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd)
        throws IOException
        {
        if(swmd.message.startsWith("=")) { processLocalStats(swmd.message, swmd.timestamp); }
        else { processRemoteStats(swmd.message, swmd.timestamp); }
        }
    }
