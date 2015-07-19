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
import java.util.Calendar;
import java.util.SortedSet;

import org.junit.Test;

import uk.org.opentrv.hdd.ContinuousDailyHDD;
import uk.org.opentrv.hdd.DDNExtractor;
import uk.org.opentrv.hdd.Util;

/**Test handling of degreedays.net input data. */
public class DDNExtractorTest
    {
    /**Sample of degreedays.net multi-base-temperature daily data with two days' values. */
    public static final String DDNSampleHeaderAndDays =
            "Description:,\"Celsius-based heating degree days for base temperatures at and around 15.5C\"\n" +
            "Source:,\"www.degreedays.net (using temperature data from www.wunderground.com)\"\n" +
            "Accuracy:,\"Estimates were made to account for missing data: the \"\"% Estimated\"\" column shows how much each figure was affected (0% is best, 100% is worst)\"\n" +
            "Station:,\"Northolt (0.42W,51.55N)\"\n" +
            "Station ID:,\"EGWU\"\n" +
            ",(Column titles show the base temperature in Celsius)\n" +
            "Date,12.5,13,13.5,14,14.5,15,15.5,16,16.5,17,17.5,18,18.5,% Estimated\n" +
            "2011-05-01,0.3,0.5,0.7,1,1.3,1.5,1.8,2.2,2.5,2.9,3.3,3.8,4.2,1\n" +
            "2011-05-02,1.7,2,2.3,2.7,3,3.4,3.9,4.3,4.8,5.3,5.8,6.3,6.8,0\n";

    /**Test parsing of degreedays.net multi-base-temperature daily data. */
    @Test public void testDDNExtract() throws Exception
        {
        try(final Reader r = new StringReader(DDNSampleHeaderAndDays))
            {
            final ContinuousDailyHDD hdd = DDNExtractor.extractForBaseTemperature(r, 15.501f);
            assertNotNull(hdd);
            assertEquals("must accept data close to specified", 15.5f, hdd.getBaseTemperatureAsFloat(), 0.1f);
            assertNotNull(hdd.getMap());
            assertEquals(2, hdd.getMap().size());
            assertEquals(Integer.valueOf(20110501), hdd.getMap().firstKey());
            assertEquals(Integer.valueOf(20110502), hdd.getMap().lastKey());
            assertEquals(1.8f, hdd.getMap().get(20110501).floatValue(), 0.001f);
            assertEquals(3.9f, hdd.getMap().get(20110502).floatValue(), 0.001f);
            }

        try(final Reader r = new StringReader(DDNSampleHeaderAndDays))
            {
            final SortedSet<Float> basetemps = DDNExtractor.availableBaseTemperatures(r);
            assertNotNull(basetemps);
            assertEquals(13, basetemps.size());
            assertEquals(12.5f, basetemps.first(), 0.01f);
            assertEquals(18.5f, basetemps.last(), 0.01f);
            }

        try(final Reader r = new StringReader(DDNSampleHeaderAndDays))
            {
            final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(r);
            assertNotNull(hdds);
            assertEquals(13, hdds.size());
            assertEquals(12.5f, hdds.first().getBaseTemperatureAsFloat(), 0.01f);
            assertEquals(18.5f, hdds.last().getBaseTemperatureAsFloat(), 0.01f);
            for(final ContinuousDailyHDD hdd : hdds)
                { assertEquals(2, hdd.getMap().size()); }
            assertEquals(15.5f, Util.findHDDWithClosestBaseTemp(hdds, 15.5f).getBaseTemperatureAsFloat(), 0.1f);
            assertEquals(12.5f, Util.findHDDWithClosestBaseTemp(hdds, 12.5f).getBaseTemperatureAsFloat(), 0.1f);
            assertEquals(16.5f, Util.findHDDWithClosestBaseTemp(hdds, 16.5f).getBaseTemperatureAsFloat(), 0.1f);
            }
        }

    /**Return a stream for the large (ASCII) sample HDD data for EGLL; never null. */
    public static InputStream getLargeEGLLHDDCSVStream()
        { return(DDNExtractorTest.class.getResourceAsStream("EGLL_HDD_15.5C+-3.0C-20140526-36M.csv")); }
    /**Return a Reader for the large sample HDD data for EGLL; never null. */
    public static Reader getLargeEGLLHDDCSVReader() throws IOException
        { return(new InputStreamReader(getLargeEGLLHDDCSVStream(), "ASCII7")); }

    /**Return a stream for the huge (ASCII) sample HDD data for EGLL; never null. */
    public static InputStream getHugeEGLLHDDCSVStream()
        { return(DDNExtractorTest.class.getResourceAsStream("EGLLLotsOfBaseTemps.csv")); }
    /**Return a Reader for the huge sample HDD data for EGLL; never null. */
    public static Reader getHugeEGLLHDDCSVReader() throws IOException
        { return(new InputStreamReader(getHugeEGLLHDDCSVStream(), "ASCII7")); }

    /**Test extraction from a substantial file. */
    @Test public void testDDNExtractLarge() throws Exception
        {
        try(final Reader r = getLargeEGLLHDDCSVReader())
            {
            assertNotNull(r);
            final ContinuousDailyHDD hdd = DDNExtractor.extractForBaseTemperature(r, 15.5f);
            assertEquals(15.5f, hdd.getBaseTemperatureAsFloat(), 0.001f);
            assertNotNull(hdd);
            assertNotNull(hdd.getMap());
            assertEquals(1121, hdd.getMap().size());
            assertEquals(Integer.valueOf(20110501), hdd.getMap().firstKey());
            assertEquals(Integer.valueOf(20140525), hdd.getMap().lastKey());
            }
        }

    /**Brief tests of date conversion to and from key. */
    @Test public void testDateKeyConversion()
        {
        final Calendar i1 = Calendar.getInstance();
        i1.set(2014, 4, 26);
        assertEquals(Integer.valueOf(20140526), Util.keyFromDate(i1));
        final Calendar i2 = Util.dateFromKey(20140525);
        assertEquals(2014, i2.get(Calendar.YEAR));
        assertEquals(4, i2.get(Calendar.MONTH));
        assertEquals(25, i2.get(Calendar.DATE));
        }
    }
