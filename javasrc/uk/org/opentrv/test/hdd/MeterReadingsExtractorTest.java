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

package uk.org.opentrv.test.hdd;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.StringReader;
import java.util.SortedMap;

import org.junit.Test;

import uk.org.opentrv.hdd.MeterReadingsExtractor;

/**Test handling of meter readings (daily) input data.
 * Dates are of the form YYYY-MM-DD or YYYY/MM/DD with optional trailing data (eg " 00:00:00").
 * There may be a leading non-numeric header line.
 */
public class MeterReadingsExtractorTest
    {
    /**Sample 1 of meter heading data. */
    public static final String sample1 =
            "2009-06-01,625\n" +
            "2009-06-08,628\n" +
            "2009-06-15,632\n" +
            "2009-06-22,636\n" +
            "2009-06-29,639\n" +
            "2009-07-06,643\n";

    /**Sample 2 of meter heading data. */
    public static final String sample2 =
            "DATE,VALUE,USETARIFF,COST\n" +
            "2014-04-27,5899.0,1,\n" +
            "2014-04-20,5897.0,1,\n" +
            "2014-03-30,5886.0,1,\n" +
            "2014-03-23,5878.0,1,\n";

    /**Sample 3 of meter heading non-cumulative data with Excel style midnight date, eg as used by Loop. */
    public static final String sample3 =
            "Time,Gas (kWh)\n" +
            "2016/03/01 00:00:00,18.88\n" +
            "2016/03/02 00:00:00,16.99\n" +
            "2016/03/03 00:00:00,14.33\n" +
            "2016/03/04 00:00:00,16.88\n";

    /**Test parsing of readings CSV. */
    @Test public void testReadingsExtract() throws Exception
        {
        try(final Reader r = new StringReader(sample1))
            {
            final SortedMap<Integer, Double> readings1 = MeterReadingsExtractor.extractMeterReadings(r);
            assertNotNull(readings1);
            assertEquals(6, readings1.size());
            assertEquals(Integer.valueOf(20090601), readings1.firstKey());
            assertEquals(Integer.valueOf(20090706), readings1.lastKey());
            assertEquals(625d, readings1.get(20090601).doubleValue(), 0.001);
            assertEquals(643d, readings1.get(20090706).doubleValue(), 0.001);
            }

        try(final Reader r = new StringReader(sample2))
            {
            final SortedMap<Integer, Double> readings2 = MeterReadingsExtractor.extractMeterReadings(r);
            assertNotNull(readings2);
            assertEquals(4, readings2.size());
            assertEquals(Integer.valueOf(20140323), readings2.firstKey());
            assertEquals(Integer.valueOf(20140427), readings2.lastKey());
            assertEquals(5878.0, readings2.get(20140323).doubleValue(), 0.001);
            assertEquals(5899.0, readings2.get(20140427).doubleValue(), 0.001);
            }

        try(final Reader r = new StringReader(sample3))
            {
            final SortedMap<Integer, Double> readings3 = MeterReadingsExtractor.extractMeterReadings(r, true);
            assertNotNull(readings3);
            assertEquals(4, readings3.size());
            assertEquals(Integer.valueOf(20160301), readings3.firstKey());
            assertEquals(Integer.valueOf(20160304), readings3.lastKey());
            assertEquals(18.88d, readings3.get(20160301).doubleValue(), 0.001);
            assertEquals(67.08d, readings3.get(20160304).doubleValue(), 0.001);
            }
        }

    /**Return a stream for the large (ASCII) sample meter data in EGLL; never null. */
    public static InputStream getLargeEGLLMeterCSVStream()
        { return(MeterReadingsExtractorTest.class.getResourceAsStream("20140526-sample-gas-use-EGLL-1.csv")); }
    /**Return a Reader for the large sample HDD data for EGLL; never null. */
    public static Reader getLargeEGLLMeterCSVReader() throws IOException
        { return(new InputStreamReader(getLargeEGLLMeterCSVStream(), "ASCII7")); }

    /**Test extraction from a substantial file. */
    @Test public void testMeterExtractLarge() throws Exception
        {
        try(final Reader r = getLargeEGLLMeterCSVReader())
            {
            assertNotNull(r);
            final SortedMap<Integer, Double> readings = MeterReadingsExtractor.extractMeterReadings(r);
            assertEquals(261, readings.size());
            assertEquals(Integer.valueOf(20090601), readings.firstKey());
            assertEquals(Integer.valueOf(20140526), readings.lastKey());
            assertEquals(625.0, readings.get(20090601).doubleValue(), 0.001);
            assertEquals(1922.0, readings.get(20120625).doubleValue(), 0.001);
            assertEquals(2561.0, readings.get(20140526).doubleValue(), 0.001);
            }
        }
    }
