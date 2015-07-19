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

import java.util.List;
import java.util.Map;
import java.util.SortedMap;
import java.util.SortedSet;

import org.junit.Test;

import uk.org.opentrv.hdd.ChangeFinder;
import uk.org.opentrv.hdd.ChangeFinder.EfficiencyChangeEvent;
import uk.org.opentrv.hdd.ContinuousDailyHDD;
import uk.org.opentrv.hdd.DDNExtractor;
import uk.org.opentrv.hdd.MeterReadingsExtractor;
import uk.org.opentrv.hdd.Util;
import uk.org.opentrv.hdd.Util.HDDMetrics;

public class ChangeFinderTest
    {
    @Test
    public void testBasicStatsCalc() throws Exception
        {
        final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(DDNExtractorTest.getLargeEGLLHDDCSVReader());
        final SortedMap<Integer, Double> meterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final ChangeFinder cf1 = new ChangeFinder(hdds, meterReadings, Util.DEFAULT_GAS_M3_TO_KWH);
        final HDDMetrics basicMetrics = cf1.getBasicFullDataMetrics();
        assertNotNull(basicMetrics);
        assertEquals(2f, basicMetrics.slopeEnergyPerHDD, 0.5f);
        final Util.OptimumFit bestFit = cf1.getBestFullDataFit();
        assertNotNull(bestFit);
//        System.out.println(bestFit);
        assertEquals(2.3f, bestFit.bestFit.slopeEnergyPerHDD, 0.1f);
        assertEquals(3f, bestFit.bestFit.interceptBaseline, 0.1f);
        assertEquals(0.83f, bestFit.bestFit.rsqFit, 0.1f);
        assertEquals(true, bestFit.eveningReads);
        assertEquals(12.5f, bestFit.hddBaseTempC, 0.1f);
        }

    @Test
    public void testByYearStatsFit() throws Exception
        {
        final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(DDNExtractorTest.getLargeEGLLHDDCSVReader());
        final SortedMap<Integer, Double> meterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final ChangeFinder cf1 = new ChangeFinder(hdds, meterReadings, Util.DEFAULT_GAS_M3_TO_KWH);
        final SortedMap<Integer,Util.OptimumFit> byYear = cf1.getBestByCalendarYearFit();
        assertNotNull(byYear);
        assertEquals(4, byYear.size());
        assertEquals(2011, byYear.firstKey().intValue());
        assertEquals(2014, byYear.lastKey().intValue());
        for(final Util.OptimumFit of : byYear.values())
            {
            assertEquals(2.3f, of.bestFit.slopeEnergyPerHDD, 0.6f);
            assertEquals(0.83f, of.bestFit.rsqFit, 0.1f);
            assertEquals(12.5f, of.hddBaseTempC, 0.1f);
            }
        }

    @Test
    public void testByYearStatsFitHuge() throws Exception
        {
        final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(DDNExtractorTest.getHugeEGLLHDDCSVReader());
        final SortedMap<Integer, Double> meterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final ChangeFinder cf1 = new ChangeFinder(hdds, meterReadings, Util.DEFAULT_GAS_M3_TO_KWH);
        final SortedMap<Integer,Util.OptimumFit> byYear = cf1.getBestByCalendarYearFit();
        assertNotNull(byYear);
        assertEquals(6, byYear.size());
        assertEquals(2009, byYear.firstKey().intValue());
        assertEquals(2014, byYear.lastKey().intValue());
        for(final Map.Entry<Integer, Util.OptimumFit> e : byYear.entrySet())
            {
            final Util.OptimumFit of = e.getValue();
            System.out.println("sample points in "+e.getKey() + " is " + of.bestFit.n);
            System.out.println("slope in "+e.getKey() + " is " + of.bestFit.slopeEnergyPerHDD);
            System.out.println("base load in "+e.getKey() + " is " + of.bestFit.interceptBaseline);
            System.out.println("optimum base temp in "+e.getKey() + " is " + of.hddBaseTempC);
            assertEquals(3.1f, of.bestFit.slopeEnergyPerHDD, 0.5f);
            assertEquals(0.83f, of.bestFit.rsqFit, 0.1f);
            assertEquals("optimum base temp in "+e.getKey(), 12.5f, of.hddBaseTempC, 2f);
            }
        }

    @Test
    public void testEfficiencyChangeEventsDetection() throws Exception
        {
        final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(DDNExtractorTest.getLargeEGLLHDDCSVReader());
        final SortedMap<Integer, Double> meterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final ChangeFinder cf1 = new ChangeFinder(hdds, meterReadings, Util.DEFAULT_GAS_M3_TO_KWH);
        final List<EfficiencyChangeEvent> efficiencyChangeEvents = cf1.getEfficiencyChangeEvents(true);
        assertNotNull(efficiencyChangeEvents);
//ECE merged/filtered: EfficiencyChangeEvent around 20130303 max 5 weeks, slope before 1.6029699 and after 2.6002436: [bad fit HDDMetrics [slope=1.2545134,baseload=12.843402,R^2=0.18699251,n=8], bad fit HDDMetrics [slope=1.2424847,baseload=12.2927065,R^2=0.18791814,n=8]]
//ECE merged/filtered: EfficiencyChangeEvent around 20131225 max 10 weeks, slope before 2.519022 and after 2.2348788: [bad fit HDDMetrics [slope=1.1174586,baseload=7.1742444,R^2=0.30437392,n=8], bad fit HDDMetrics [slope=0.6736139,baseload=10.798448,R^2=0.09188299,n=8], bad fit HDDMetrics [slope=0.69028705,baseload=10.695496,R^2=0.04158823,n=8], bad fit HDDMetrics [slope=1.5820115,baseload=6.6400757,R^2=0.22738977,n=8], bad fit HDDMetrics [slope=1.7081335,baseload=6.0599313,R^2=0.28771016,n=8], bad fit HDDMetrics [slope=1.475564,baseload=7.8680186,R^2=0.22779997,n=8], bad fit HDDMetrics [slope=0.97867054,baseload=11.6043215,R^2=0.110588476,n=8]]
//ECE merged/filtered: EfficiencyChangeEvent around 20140129 max 4 weeks, slope before 2.2348788 and after 1.3378577: [bad fit HDDMetrics [slope=2.538432,baseload=3.4905486,R^2=0.47185862,n=8]]
        assertEquals(3, efficiencyChangeEvents.size());
        assertEquals(20130303, Util.keyFromDate(efficiencyChangeEvents.get(0).midPoint()).intValue());
        assertEquals(1.60f, efficiencyChangeEvents.get(0).preEff.slopeEnergyPerHDD, 0.1f);
        assertEquals(2.60f, efficiencyChangeEvents.get(0).postEff.slopeEnergyPerHDD, 0.1f);
        assertEquals(20131225, Util.keyFromDate(efficiencyChangeEvents.get(1).midPoint()).intValue());
        assertEquals(2.52f, efficiencyChangeEvents.get(1).preEff.slopeEnergyPerHDD, 0.1f);
        assertEquals(2.23f, efficiencyChangeEvents.get(1).postEff.slopeEnergyPerHDD, 0.1f);
        assertEquals(20140129, Util.keyFromDate(efficiencyChangeEvents.get(2).midPoint()).intValue());
        assertEquals(2.23f, efficiencyChangeEvents.get(2).preEff.slopeEnergyPerHDD, 0.1f);
        assertEquals(1.34f, efficiencyChangeEvents.get(2).postEff.slopeEnergyPerHDD, 0.1f);
        }

    @Test
    public void testEfficiencyChangeEventsDetectionHuge() throws Exception
        {
        final SortedSet<ContinuousDailyHDD> hdds = DDNExtractor.extractForAllBaseTemperatures(DDNExtractorTest.getHugeEGLLHDDCSVReader());
        final SortedMap<Integer, Double> meterReadings = MeterReadingsExtractor.extractMeterReadings(MeterReadingsExtractorTest.getLargeEGLLMeterCSVReader());
        final ChangeFinder cf1 = new ChangeFinder(hdds, meterReadings, Util.DEFAULT_GAS_M3_TO_KWH);
        assertEquals("should match expected (low) base temp", 11.0f, cf1.getBestFullDataFit().hddBaseTempC, 0.1f);
        final List<EfficiencyChangeEvent> efficiencyChangeEvents = cf1.getEfficiencyChangeEvents(true);
        assertNotNull(efficiencyChangeEvents);
        assertEquals(7, efficiencyChangeEvents.size());

//ECE merged/filtered: EfficiencyChangeEvent around 20091018 max 9 weeks, slope before 6.4955635 and after 1.839515: [bad fit HDDMetrics [slope=4.307626,baseload=7.2060676,R^2=0.21740985,n=8], bad fit HDDMetrics [slope=4.153566,baseload=7.433409,R^2=0.41031304,n=8], bad fit HDDMetrics [slope=3.4224591,baseload=8.279117,R^2=0.44851777,n=8], bad fit HDDMetrics [slope=1.9949455,baseload=11.09204,R^2=0.13318826,n=8], bad fit HDDMetrics [slope=1.4720297,baseload=12.547051,R^2=0.11358787,n=8], bad fit HDDMetrics [slope=2.7743344,baseload=12.513365,R^2=0.46625912,n=8]]
// 2009/10: heating on mid-month.
// 2009/10/25: put up closer-fitting lined curtains in the living-room.
// 2009/11/02: replaced the outer seal/gasket (and fitted a "weather bar") on our living-room double-glazed doors, mainly to keep out leaks from heavy rain but partly to reduce draughts.

//ECE merged/filtered: EfficiencyChangeEvent around 20100117 max 5 weeks, slope before 1.839515 and after 1.8837337: [bad fit HDDMetrics [slope=1.6565908,baseload=23.952427,R^2=0.4767263,n=8], bad fit HDDMetrics [slope=1.6675124,baseload=23.669792,R^2=0.45107806,n=8]]
// 2010/01: mean temperatures 2.5C or more below 1971--2000 normal.

//ECE merged/filtered: EfficiencyChangeEvent around 20100203 max 4 weeks, slope before 1.8837337 and after 3.757735: [bad fit HDDMetrics [slope=2.2262566,baseload=18.931644,R^2=0.45714948,n=8]]
// 2010/02: coldest February since 1991.

//ECE merged/filtered: EfficiencyChangeEvent around 20101006 max 4 weeks, slope before 1.097864 and after 1.847261: [bad fit HDDMetrics [slope=1.1865276,baseload=6.5226417,R^2=0.3934205,n=8]]
// 2010/10: heating on mid-month.

//ECE merged/filtered: EfficiencyChangeEvent around 20110206 max 9 weeks, slope before 1.847261 and after 2.4909377: [bad fit HDDMetrics [slope=1.1941011,baseload=18.06664,R^2=0.32958654,n=8], bad fit HDDMetrics [slope=1.6249591,baseload=15.709352,R^2=0.44314578,n=8], bad fit HDDMetrics [slope=1.5528905,baseload=15.936742,R^2=0.44305167,n=8], bad fit HDDMetrics [slope=1.83777,baseload=13.987124,R^2=0.46618664,n=8], bad fit HDDMetrics [slope=1.8857759,baseload=13.114601,R^2=0.42271248,n=8], bad fit HDDMetrics [slope=2.2357113,baseload=10.400906,R^2=0.37370476,n=8]]
// 2011/02/26: took delivery of another 170mm (rockwool) loft insulation to try to ensure that we exceed building regs wherever possible.

//ECE merged/filtered: EfficiencyChangeEvent around 20130303 max 5 weeks, slope before 1.7435868 and after 2.9701653: [bad fit HDDMetrics [slope=0.98010045,baseload=16.839697,R^2=0.14184208,n=8], bad fit HDDMetrics [slope=1.151979,baseload=14.686999,R^2=0.19461425,n=8]]
// 2013/02/27: (re)installing TRV in living room and starting roll-out soft-zoning (room-by-room open-source electronic TRV control and calls for heat from the boiler) rather than just a single house thermostat.
// 2013/03: coldest month here since 2010/12.

//ECE merged/filtered: EfficiencyChangeEvent around 20140105 max 13 weeks, slope before 3.035492 and after 1.7347778: [bad fit HDDMetrics [slope=1.4282633,baseload=7.500992,R^2=0.34706762,n=8], bad fit HDDMetrics [slope=0.19977197,baseload=13.676263,R^2=0.0063990992,n=8], bad fit HDDMetrics [slope=-0.40679184,baseload=15.781644,R^2=0.013972017,n=8], bad fit HDDMetrics [slope=0.9981335,baseload=11.24999,R^2=0.086652026,n=8], bad fit HDDMetrics [slope=1.1853285,baseload=10.61432,R^2=0.14737631,n=8], bad fit HDDMetrics [slope=1.2075393,baseload=11.205961,R^2=0.16664238,n=8], bad fit HDDMetrics [slope=0.8776411,baseload=13.487281,R^2=0.10109251,n=8], bad fit HDDMetrics [slope=2.0044491,baseload=8.997301,R^2=0.39792308,n=8], bad fit HDDMetrics [slope=1.8308024,baseload=10.237343,R^2=0.26389945,n=8], bad fit HDDMetrics [slope=2.5973237,baseload=6.621253,R^2=0.49762535,n=8]]
// 2013/11/15: heating on (for a couple of days it had been on intermittently), under OpenTRV control.
// 2013/12: house down to ~12C (minimum ~10C) after three days empty and only frost protection with outside temps down to ~3C.
// 2013/12: All rooms now OpenTRV heating zones.
// 2014/02: Mildest February (lowest HDD12) in my records.
// 2014/02/17: replaced boiler primary heat exchanger full of many years' worth of scale.
// 2014/03/14: fitted additional external bypass as boiler internal one working but not really up to the job with rejuvenated exchanger (and had been having to leave hall rad on as bypass).


        }

    }
