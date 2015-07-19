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
import java.io.EOFException;
import java.io.IOException;
import java.io.Reader;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.SortedMap;
import java.util.SortedSet;
import java.util.TimeZone;
import java.util.TreeMap;
import java.util.TreeSet;

/**Extracts HDD information from a degreeday.net format ASCII CSV reader/stream.
 * In particular, given a desired base temperature and a file
 * containing (daily) heating degree day values
 * of the following form with a column for that base temperature,
 * returns a ContinuousDailyHDD instance containing the data.
<pre>
Description:,"Celsius-based heating degree days for base temperatures at and around 15.5C"
Source:,"www.degreedays.net (using temperature data from www.wunderground.com)"
Accuracy:,"Estimates were made to account for missing data: the ""% Estimated"" column shows how much each figure was affected (0% is best, 100% is worst)"
Station:,"Northolt (0.42W,51.55N)"
Station ID:,"EGWU"
,(Column titles show the base temperature in Celsius)
Date,12.5,13,13.5,14,14.5,15,15.5,16,16.5,17,17.5,18,18.5,% Estimated
2011-05-01,0.3,0.5,0.7,1,1.3,1.5,1.8,2.2,2.5,2.9,3.3,3.8,4.2,1
2011-05-02,1.7,2,2.3,2.7,3,3.4,3.9,4.3,4.8,5.3,5.8,6.3,6.8,0
</pre>
 */
public final class DDNExtractor
    {
    private DDNExtractor() { /* prevent instance creation */ }

    /**Allowed difference between requested base temperature and available, to allow for rounding errors. */
    public static final float BASE_TEMP_EPSILON = 1e-2f;

    /**Extract the (immutable) set of available base temperatures; never null nor empty (nor containing null/NaN/Inf).
     * Does NOT close the Reader.
     * @return set of base temperatures (at least one); never null/empty
     * @throws IOException  if file is not readable or does not contain suitable data
     */
    public static SortedSet<Float> availableBaseTemperatures(final Reader r)
        throws IOException
        {
        if(null == r) { throw new IllegalArgumentException(); }

        // Wrap in BufferedReader if required.
        @SuppressWarnings("resource")
        final BufferedReader br = (r instanceof BufferedReader) ? ((BufferedReader) r) : new BufferedReader(r);

        // Discard header lines until encountering the first one starting with "Date" as its first field.
        // Remaining fields on that line are base temperatures.
        String line;
        while(null != (line = br.readLine()))
            {
            if(!line.startsWith("Date,")) { continue; }
            final String fields[] = Util.splitCSVLine(line);
            if((fields.length > 0) && "Date".equals(fields[0]))
                {
                final SortedSet<Float> result = new TreeSet<>();
                for(int i = 1; i < fields.length; ++i)
                    {
                    final float f;
                    try { f = Float.parseFloat(fields[i]); }
                    catch(final NumberFormatException e) { continue; } // Ignore non-numbers.
                    if(Float.isNaN(f) || Float.isInfinite(f)) { continue; } // Ignore non-numbers.
                    result.add(f);
                    }
                if(result.isEmpty()) { throw new IOException("no base temperatures found"); }
                return(Collections.unmodifiableSortedSet(result));
                }
            }
        // Exception in common 'bad' case, eg wrong sort of file.
        throw new EOFException("no suitable data found");
        }

    /**Extract HDD for specified base temperature from DDN-style multi-base-temperature CSV; never null.
     * Does NOT close the Reader.
     * @param r ASCII CSV file in degreedays.net-like format (Date line followed by HDD values); never null
     * @throws IOException in case of parse error or missing data
     */
    public static ContinuousDailyHDD extractForBaseTemperature(final Reader r, final float baseTemperature)
        throws IOException
        {
        final SortedSet<ContinuousDailyHDD> hdds = extractForAllBaseTemperatures(r);
        final ContinuousDailyHDD hdd = Util.findHDDWithClosestBaseTemp(hdds, baseTemperature);
        if(Math.abs(baseTemperature - hdd.getBaseTemperatureAsFloat()) > BASE_TEMP_EPSILON) { throw new IOException("close enough base temperature not found in data"); }
        return(hdd);
        }

//    /**Extract HDD for specified base temperature from DDN-style multi-base-temperature CSV; never null.
//     * Does NOT close the Reader.
//     * @param r ASCII CSV file in degreedays.net-like format (Date line followed by HDD values); never null
//     * @throws IOException in case of parse error or missing data
//     */
//    public static ContinuousDailyHDD extractForBaseTemperature(final Reader r, final float baseTemperature)
//        throws IOException
//        {
//        if(null == r) { throw new IllegalArgumentException(); }
//
//        // Wrap in BufferedReader if required.
//        final BufferedReader br = (r instanceof BufferedReader) ? ((BufferedReader) r) : new BufferedReader(r);
//
//        // Discard header lines until encountering the first one starting with "Date" as its first field.
//        // Remaining fields on that line are base temperatures,
//        // form which the one (or close) to that requested has to be selected.
//        String line;
//        int col = -1; // Data column to use.
//        float bt = -1; // Actual base temperature.
//        findcol: while(null != (line = br.readLine()))
//            {
//            if(!line.startsWith("Date,")) { continue; }
//            final String fields[] = Util.splitCSVLine(line);
//            if((fields.length > 0) && "Date".equals(fields[0]))
//                {
//                for(int i = 1; i < fields.length; ++i)
//                    {
//                    final float f;
//                    try { f = Float.parseFloat(fields[i]); }
//                    catch(final NumberFormatException e) { continue; } // Ignore non-numbers.
//                    if(Float.isNaN(f) || Float.isInfinite(f)) { continue; } // Ignore non-numbers.
//                    if(Math.abs(baseTemperature - f) < BASE_TEMP_EPSILON)
//                        {
//                        col = i;
//                        bt = f;
//                        break findcol;
//                        }
//                    }
//                throw new IOException("requested base temperature not found: " + baseTemperature + " in " + line);
//                }
//            }
//        // Exception in common 'bad' case, eg wrong sort of file.
//        if(null == line) { throw new EOFException("no data found"); }
//
//        // Build up map.
//        final SortedMap<Integer, Float> m = new TreeMap<>();
//        final Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
//        while(null != (line = br.readLine()))
//            {
//            final String fields[] = Util.splitCSVLine(line);
//            if(fields.length <= col) { throw new IOException("malformed row (insufficient columms): " + line); }
//            final float hdd;
//            final int year;
//            final int month;
//            final int day;
//            final Integer key;
//            final String d = fields[0];
//            if((10 != d.length()) || ('-' != d.charAt(4)) || ('-' != d.charAt(7)))
//                { throw new IOException("bad date, expecting YYYY-MM-DD: " + d); }
//            try
//                {
//                year = Integer.parseInt(d.substring(0, 4), 10);
//                month = Integer.parseInt(d.substring(5, 7), 10);
//                day = Integer.parseInt(d.substring(8), 10);
//                hdd = Float.parseFloat(fields[col]);
//                }
//            catch(final NumberFormatException e)
//                { throw new IOException("unable to parse row: " + line, e); }
//            if(hdd < 0) { throw new IOException("bad (negative) HDD value in row: " + line); }
//            // Check that dates are strictly monotonically increasing and without gaps.
//            key = (year * 10000) + (month * 100) + day;
//            if(!m.isEmpty())
//                {
//                final Integer pdkey = m.lastKey();
//                if(pdkey.intValue() >= key) { throw new IOException("misordered date in row: " + line); }
//                final Calendar prevDay = ((Calendar) cal.clone());
//                prevDay.set(year, month-1, day);
//                prevDay.add(Calendar.DAY_OF_MONTH, -1);
//                if(!Util.keyFromDate(prevDay).equals(pdkey))  { throw new IOException("date gap before row: " + line); }
//                }
//            m.put(key, hdd);
//            }
//
//        // Return immutable result.
//        final float baseTemp = bt;
//        final SortedMap<Integer, Float> im = Collections.unmodifiableSortedMap(m);
//        return(new ContinuousDailyHDD(){
//            @Override public float getBaseTemperatureAsFloat() { return(baseTemp); }
//            @Override public SortedMap<Integer, Float> getMap() { return(im); }
//            });
//        }

    /**Extract all HDD set for provided base temperatures from DDN-style multi-base-temperature CSV; never null.
     * Does NOT close the Reader.
     * @param r ASCII CSV file in degreedays.net-like format (Date line followed by HDD values); never null
     * @throws IOException in case of parse error or missing data
     */
    public static SortedSet<ContinuousDailyHDD> extractForAllBaseTemperatures(final Reader r)
        throws IOException
        {
        if(null == r) { throw new IllegalArgumentException(); }

        // Wrap in BufferedReader if required.
        @SuppressWarnings("resource")
        final BufferedReader br = (r instanceof BufferedReader) ? ((BufferedReader) r) : new BufferedReader(r);

        // Discard header lines until encountering the first one starting with "Date" as its first field.
        // Remaining fields on that line are base temperatures,
        // form which the one (or close) to that requested has to be selected.
        final List<Float> baseTempByColumn = new ArrayList<>();
        String line;
        while(null != (line = br.readLine()))
            {
            if(!line.startsWith("Date,")) { continue; }
            final String fields[] = Util.splitCSVLine(line);
            if((fields.length > 0) && "Date".equals(fields[0]))
                {
                baseTempByColumn.add(null);
                for(int i = 1; i < fields.length; ++i)
                    {
                    final float f;
                    try { f = Float.parseFloat(fields[i]); }
                    catch(final NumberFormatException e) { break; } // Stop at non-number.
                    if(Float.isNaN(f) || Float.isInfinite(f)) { break; } // Stop at non-number.
                    baseTempByColumn.add(f);
                    }
                }
            break;
            }
        if(baseTempByColumn.size() < 2) { throw new EOFException("no base temperature data found"); }
        // Exception in common 'bad' case, eg wrong sort of file.
        if(null == line) { throw new EOFException("no data found"); }

        // Number of different base temperatures (column 0 is null).
        final int nTemps = baseTempByColumn.size() - 1;

        // Build up maps.
        final List<SortedMap<Integer, Float>> m = new ArrayList<>(nTemps);
        for(int i = nTemps; --i >= 0; ) { m.add(new TreeMap<Integer, Float>()); }
        final Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        while(null != (line = br.readLine()))
            {
            final String fields[] = Util.splitCSVLine(line);
            if(fields.length <= nTemps) { throw new IOException("malformed row (insufficient columms): " + line); }
            final int year;
            final int month;
            final int day;
            final Integer key;
            final String d = fields[0];
            final float[] values = new float[fields.length-1];
            if((10 != d.length()) || ('-' != d.charAt(4)) || ('-' != d.charAt(7)))
                { throw new IOException("bad date, expecting YYYY-MM-DD: " + d); }
            try
                {
                year = Integer.parseInt(d.substring(0, 4), 10);
                month = Integer.parseInt(d.substring(5, 7), 10);
                day = Integer.parseInt(d.substring(8), 10);
                for(int i = nTemps; --i >= 0; )
                    {
                    final float v = Float.parseFloat(fields[i+1]);
                    if(v < 0) { throw new IOException("bad (negative) HDD value in row: " + line); }
                    values[i] = v;
                    }
                }
            catch(final NumberFormatException e)
                { throw new IOException("unable to parse row: " + line, e); }
            // Check that dates are strictly monotonically increasing and without gaps.
            key = (year * 10000) + (month * 100) + day;
            if(!m.get(0).isEmpty())
                {
                final Integer pdkey = m.get(0).lastKey();
                if(pdkey.intValue() >= key) { throw new IOException("misordered date in row: " + line); }
                final Calendar prevDay = ((Calendar) cal.clone());
                prevDay.set(year, month-1, day);
                prevDay.add(Calendar.DAY_OF_MONTH, -1);
                if(!Util.keyFromDate(prevDay).equals(pdkey))  { throw new IOException("date gap before row: " + line); }
                }
            for(int i = nTemps; --i >= 0; )
                { m.get(i).put(key, values[i]); }
            }

        // Return immutable result.
        final SortedSet<ContinuousDailyHDD> result = new TreeSet<>();
        for(int i = 0; i < nTemps; ++i)
            {
            final float baseTemp = baseTempByColumn.get(i+1);
            final SortedMap<Integer, Float> im = Collections.unmodifiableSortedMap(m.get(i));
            result.add(new ContinuousDailyHDD(){
                @Override public float getBaseTemperatureAsFloat() { return(baseTemp); }
                @Override public SortedMap<Integer, Float> getMap() { return(im); }
                });
            }
        return(Collections.unmodifiableSortedSet(result));
        }

//    /**UTC date-only format for Excel/CSV dates; hold lock on this instance while using for thread-safety. */
//    private static final SimpleDateFormat dateYYYYdMMdDDForCSV = new SimpleDateFormat("yyyy-MM-dd Z");
//    { dateYYYYdMMdDDForCSV.setTimeZone(TimeZone.getTimeZone("UTC")); }
    }
