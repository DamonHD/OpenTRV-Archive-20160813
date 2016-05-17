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

package uk.org.opentrv.hdd;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.Reader;
import java.util.Collections;
import java.util.SortedMap;
import java.util.TreeMap;


/**Extracts energy meter readings from an ASCII CSV reader/stream.
 * This expects an input where the first column is (or starts with)
 * a YYYY-MM-DD or YYYY/MM/DD date
 * and the second column is an (ascending) meter reading.
 * Everything else is ignored.
 * <p>
 * This will reject input where values go down at any point,
 * unless given specific instructions how to handle such elements,
 * eg due to meter roll-over or meter replacement.
 * <p>
 * This does not attempt to interpret units.
 * <p>
 * This attempts to be generous in what it accepts,
 * and in particular:
 * <ul>will attempt to quietly ignore any time element in the date field/column</li>
 * <li>will ignore unparseable lines (eg header lines)</li>
 * <li>will attempt to ignore all but the (leading) date in a date/time field (eg a trailing 00:00:00)</li>
 * <li>does not expect values for every days</li>
 * <li>will accept out-of-order values</li>
 * </ul>
 * <p>
 * Sample of acceptable input:
<pre>
DATE,VALUE,USETARIFF,COST
2014-04-27,5899.0,1,
2014-04-20,5897.0,1,
2014-04-13,5894.0,1,
2014-04-06,5890.0,1,
2014-03-30,5886.0,1,
2014-03-23,5878.0,1,
</pre>
 * <p>
 * And another:
<pre>
2009-06-01,625
2009-06-08,628
2009-06-15,632
2009-06-22,636
2009-06-29,639
2009-07-06,643
</pre>
 * <p>
 * And another:
<pre>
Time,Gas (kWh)
2016/03/01 00:00:00,18.88
2016/03/02 00:00:00,16.99
2016/03/03 00:00:00,14.33
2016/03/04 00:00:00,16.88
2016/03/05 00:00:00,17.77
</pre>
 */
public final class MeterReadingsExtractor
    {
    private MeterReadingsExtractor() { /* prevent instance creation */ }

    /**Extract meter readings from CSV as map from YYYYMMDD date key to reading as supplied; never null.
     * Rejects data where readings go down over time.
     * <p>
     * Does NOT close the Reader.
     *
     * @return immutable non-null map of monotonically-increasing readings by date
     * @throws IOException in case of parse error or missing or ambiguous or non-monotonic data
     */
    public static SortedMap<Integer, Double> extractMeterReadings(final Reader r)
        throws IOException
        {
        if(null == r) { throw new IllegalArgumentException(); }

        // Wrap in BufferedReader if required.
        final BufferedReader br = (r instanceof BufferedReader) ? ((BufferedReader) r) : new BufferedReader(r);

        final SortedMap<Integer, Double> m = new TreeMap<>();

        String line;
        while(null != (line = br.readLine()))
            {
            final String fields[] = Util.splitCSVLine(line);
            if(fields.length < 2) { continue; }
            final int year;
            final int month;
            final int day;
            final Integer key;
            final String d = fields[0];
            final Double reading;
            if((10 > d.length()) || ('-' != d.charAt(4)) || ('-' != d.charAt(7)))
                { continue; }
            try
                {
                year = Integer.parseInt(d.substring(0, 4), 10);
                month = Integer.parseInt(d.substring(5, 7), 10);
                day = Integer.parseInt(d.substring(8), 10);
                reading = Double.parseDouble(fields[1]);
                }
            catch(final NumberFormatException e)
                { continue; } // Skip bad line.
            if(Double.isNaN(reading)) { continue; } // Skip bad line.
            if(Double.isInfinite(reading)) { continue; } // Skip bad line.
            key = (year * 10000) + (month * 100) + day;
            m.put(key, reading);
            }
        // Ensure that values increase monotonically with date,
        // though not strictly since successive values can be the same.
        Double prev = null;
        for(final Double v : m.values())
            {
            if((null != prev) && (v.doubleValue() < prev))
                { throw new IOException("meter reading goes backwards after " + prev); }
            prev = v;
            }

        return(Collections.unmodifiableSortedMap(m));
        }

    }
