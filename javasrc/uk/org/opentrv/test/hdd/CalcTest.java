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
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.StringReader;
import java.util.Calendar;
import java.util.Collection;
import java.util.Random;
import java.util.SortedMap;
import java.util.SortedSet;

import org.junit.Test;

import uk.org.opentrv.hdd.ChangeFinder;
import uk.org.opentrv.hdd.ConsumptionHDDTuple;
import uk.org.opentrv.hdd.ContinuousDailyHDD;
import uk.org.opentrv.hdd.DDNExtractor;
import uk.org.opentrv.hdd.MeterReadingsExtractor;
import uk.org.opentrv.hdd.Util;
import uk.org.opentrv.hdd.Util.HDDMetrics;

public class CalcTest
    {
    @Test
    public void testCombineMeterReadingsWithHDDFail() throws Exception
        {
        try
            {
            Util.combineMeterReadingsWithHDD(null, null, rnd.nextBoolean());
            fail("should reject bad arguments");
            }
        catch(final IllegalArgumentException e) { /* expected */ }
        }

    /**Minimal sample of meter readings (two samples, spanning a month end). */
    private static final String minReadingsSample =
            "2014-04-28,2549\n" +
            "2014-05-05,2552\n";

    /**Sample of HDDs that more than spans minReadingsSample. */
    private static final String sampleHDD =
            "Date,12.5,13,13.5,14,14.5,15,15.5,16,16.5,17,17.5,18,18.5,% Estimated\n" +
            "2014-04-25,2.4,2.9,3.4,3.9,4.4,4.9,5.4,5.9,6.4,6.9,7.4,7.9,8.4,0\n" +
            "2014-04-26,1.5,1.8,2.1,2.5,2.9,3.3,3.8,4.3,4.8,5.3,5.8,6.3,6.8,0\n" +
            "2014-04-27,1.3,1.6,2,2.4,2.9,3.4,3.9,4.4,4.9,5.4,5.9,6.4,6.9,0\n" +
            "2014-04-28,1,1.3,1.6,1.9,2.2,2.6,3,3.3,3.8,4.2,4.7,5.2,5.7,0\n" +
            "2014-04-29,1.1,1.3,1.6,1.9,2.2,2.5,2.9,3.3,3.8,4.3,4.8,5.3,5.8,0\n" +
            "2014-04-30,1.9,2.2,2.5,2.8,3.1,3.4,3.7,4.1,4.4,4.7,5.1,5.5,6,0\n" +
            "2014-05-01,1.2,1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,0\n" +
            "2014-05-02,2.4,2.9,3.4,3.9,4.4,4.9,5.4,5.9,6.4,6.9,7.4,7.9,8.4,0\n" +
            "2014-05-03,3.8,4.2,4.6,5,5.5,6,6.5,7,7.5,8,8.5,9,9.5,0\n" +
            "2014-05-04,2.6,2.9,3.2,3.5,3.8,4.2,4.6,5,5.5,6,6.5,7,7.5,0\n" +
            "2014-05-05,2,2.2,2.4,2.6,2.8,3.1,3.3,3.6,4,4.3,4.7,5.1,5.6,0\n" +
            "2014-05-06,0.1,0.2,0.4,0.6,0.9,1.2,1.5,1.8,2.1,2.5,2.8,3.2,3.7,1\n" +
            "2014-05-07,0.4,0.6,0.9,1.2,1.5,1.9,2.3,2.7,3.2,3.7,4.2,4.7,5.2,0\n" +
            "2014-05-08,0.4,0.6,0.9,1.3,1.6,2,2.4,2.9,3.4,3.9,4.4,4.9,5.4,0\n";

    @Test
    public void testCombineMeterReadingsWithHDD() throws Exception
        {
        final Collection<ConsumptionHDDTuple> ds1eve = Util.combineMeterReadingsWithHDD(
                MeterReadingsExtractor.extractMeterReadings(new StringReader(minReadingsSample)),
                DDNExtractor.extractForBaseTemperature(new StringReader(sampleHDD), 12.5f),
                true);
        assertEquals(1, ds1eve.size());
        assertEquals(20140505, ds1eve.iterator().next().endReadingDateYYYYMMDD);
        assertEquals(7, ds1eve.iterator().next().hddDays);
        assertEquals(1.1+1.9+1.2+2.4+3.8+2.6+2, ds1eve.iterator().next().hdd, 0.0001);
        assertEquals(2552-2549, ds1eve.iterator().next().consumption, 0.0001);

        final Collection<ConsumptionHDDTuple> ds2eve = Util.combineMeterReadingsWithHDD(
                MeterReadingsExtractor.extractMeterReadings(new StringReader(minReadingsSample)),
                DDNExtractor.extractForBaseTemperature(new StringReader(sampleHDD), 12.5f),
                false);
        assertEquals(1, ds2eve.size());
        assertEquals(20140505, ds2eve.iterator().next().endReadingDateYYYYMMDD);
        assertEquals(7, ds2eve.iterator().next().hddDays);
        assertEquals(1+1.1+1.9+1.2+2.4+3.8+2.6, ds2eve.iterator().next().hdd, 0.0001);
        assertEquals(2552-2549, ds2eve.iterator().next().consumption, 0.0001);

        // Combination of real substantial data sets.
        final ContinuousDailyHDD hdd = DDNExtractor.extractForBaseTemperature(DDNExtractorTest.getLargeEGLLHDDCSVReader(), 12.5f);
        final SortedMap<Integer, Double> allMeterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final SortedMap<Integer, Double> trimmedMeterReadings = allMeterReadings.tailMap(hdd.getMap().firstKey()).headMap(hdd.getMap().lastKey());
        assertEquals(160, trimmedMeterReadings.size());
        // Compute as if for evening readings.
        final SortedSet<ConsumptionHDDTuple> readingsWithHDDpm = Util.combineMeterReadingsWithHDD(
                trimmedMeterReadings,
                hdd,
                true);
        assertEquals(159, readingsWithHDDpm.size());
        final SortedSet<ConsumptionHDDTuple> normalisedpm = Util.normalisedMeterReadingsWithHDD(readingsWithHDDpm, 11.1f);
        // Compute metrics over entire (pm) data set.
        final HDDMetrics metricspm = Util.computeHDDMetrics(normalisedpm);
        assertNotNull(metricspm);
//        System.out.println("From " + trimmedMeterReadings.firstKey() + " to " + trimmedMeterReadings.lastKey());
//        System.out.println("PM metrics: "+metricspm);
        assertEquals("slope ~ 2.3kWh/HDD12.5", 2.31f, metricspm.slopeEnergyPerHDD, 0.05f);
        assertEquals("baseline usage ~ 3kWh/d", 2.95f, metricspm.interceptBaseline, 0.05f);
        assertEquals("R^2", 0.8f, metricspm.rsqFit, 0.1f);

        // Recompute as if for morning readings.
        final SortedSet<ConsumptionHDDTuple> normalisedam = Util.normalisedMeterReadingsWithHDD(Util.combineMeterReadingsWithHDD(
                trimmedMeterReadings,
                hdd,
                false), 11.1f);
        assertEquals(159, normalisedam.size());
        // Compute metrics over entire (am) data set.
        final HDDMetrics metricsam = Util.computeHDDMetrics(normalisedam);
//        System.out.println("AM metrics: "+metricsam);
//        System.out.println("R^2 pm = " + metrics.rsqFit + " vs am " + metricsam.rsqFit);
        assertTrue("evening readings should be a better fit (higher R^2)", metricsam.rsqFit < metricspm.rsqFit);

        // Check a year of data at a time...
        for(int year = 2011; year < 2014; ++year)
            {
            final ConsumptionHDDTuple startKey = new ConsumptionHDDTuple((year * 1_00_00) + 5_00 + 1);
            final ConsumptionHDDTuple endKey =  new ConsumptionHDDTuple(((year + 1) * 1_00_00) + 4_00 + 30);
//            System.out.println("Year from " + startKey.endReadingDateYYYYMMDD + " to " + endKey.endReadingDateYYYYMMDD);
            for(final boolean pm : new boolean[]{false, true})
                {
                final SortedSet<ConsumptionHDDTuple> data = pm ? normalisedpm : normalisedam;
                final SortedSet<ConsumptionHDDTuple> dataFiltered = data.tailSet(startKey).headSet(endKey);
                final HDDMetrics metrics = Util.computeHDDMetrics(dataFiltered);
//                System.out.print(pm ? "PM readings: " : "AM readings: ");
//                System.out.println(metrics);
                assertEquals("slope ~ 2.3kWh/HDD12.5", 2.3f, metrics.slopeEnergyPerHDD, 0.1f);
                assertEquals("baseline usage ~ 3kWh/d", 3f, metrics.interceptBaseline, 1f);
                assertEquals("R^2 ~ 0.8", 0.8f, metrics.rsqFit, 0.1f);
                }
            }

        // Count of available samples and successful fits at shortest window.
        int availableSmallWindows = 0, goodSmallWindows = 0;
        for(final ConsumptionHDDTuple datum : normalisedpm)
            {
            for(int w = 0; w < ChangeFinder.DEFAULT_WINDOW_SIZES_W.size(); ++w)
                {
                final int weeksWindow = ChangeFinder.DEFAULT_WINDOW_SIZES_W.get(w);

                // Line results up by end date.
                final int end = datum.endReadingDateYYYYMMDD;
                final int endMonth = (end / 100) % 100;
                final boolean isHeatingSeasonEndMonth = ChangeFinder.isTypicallyUKHeatingSeasonMonth(endMonth);
                final Calendar tmpC = Util.dateFromKey(end);
                tmpC.add(Calendar.WEEK_OF_YEAR, -weeksWindow);
                final int start = Util.keyFromDate(tmpC);

                final ConsumptionHDDTuple startKey = new ConsumptionHDDTuple(start);
                final ConsumptionHDDTuple endKey =  new ConsumptionHDDTuple(end);
                for(final boolean pm : new boolean[]{/*false,*/ true})
                    {
                    final SortedSet<ConsumptionHDDTuple> data = pm ? normalisedpm : normalisedam;
                    final SortedSet<ConsumptionHDDTuple> dataFiltered = data.tailSet(startKey).headSet(endKey);
                    if(dataFiltered.size() < ChangeFinder.DEFAULT_MIN_REGRESSION_DATA_POINTS) { continue; } // Too small a data set.
                    if((w > 0) && (dataFiltered.size() <= ((3*weeksWindow)/4))) { continue; } // Too few data points compared to target window size.
                    if(isHeatingSeasonEndMonth && (0 == w)) { ++availableSmallWindows; }
//                    System.out.print("data points from " + dataFiltered.first().endReadingDateYYYYMMDD + " to " + dataFiltered.last().endReadingDateYYYYMMDD + ": ");
                    final HDDMetrics metrics;
                    try { metrics = Util.computeHDDMetrics(dataFiltered); }
                    catch(final IllegalArgumentException e)
                        {
                        System.out.println("CANNOT COMPUTE");
                        continue; // Poor data sets.
                        }
                    if((metrics.slopeEnergyPerHDD < 0) ||
                       (metrics.interceptBaseline < 0) ||
                       (metrics.rsqFit < ChangeFinder.DEFAULT_MIN_RSQUARED))
                        {
//                        System.out.println("BAD FIT @ n="+metrics.n);
                        continue;
                        }
                    if(isHeatingSeasonEndMonth && (0 == w)) { ++goodSmallWindows; }
//                    System.out.print(pm ? "PM readings: " : "AM readings: ");
//                    System.out.println(metrics);
                    assertEquals("slope ~ 2.3kWh/HDD12.5", 2.3f, metrics.slopeEnergyPerHDD, 1.7f);
                    }
                }
            }
        assertTrue("must be able to fit enough at small window size, got "+goodSmallWindows+"/"+availableSmallWindows, goodSmallWindows >= (availableSmallWindows/2));
        }

    /**Test some date arithmetic. */
    @Test
    public void testDateDiff()
        {
        assertEquals(0, Util.daysBetweenDateKeys(20120101, 20120101));
        assertEquals(1, Util.daysBetweenDateKeys(20120101, 20120102));
        assertEquals(2, Util.daysBetweenDateKeys(20120101, 20120103));
        assertEquals(31, Util.daysBetweenDateKeys(20120101, 20120201));
        assertEquals("must work across DST boundary", 1, Util.daysBetweenDateKeys(20070324, 20070325));
        }

    /**Test basic change finding. */
    @Test
    public void testChangeFinder()
        {
        try { new ChangeFinder(null, null, 0f); fail("must reject bad args"); } catch(final IllegalArgumentException e) { /* expected */ }
        }


    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
