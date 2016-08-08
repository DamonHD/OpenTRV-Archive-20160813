package uk.org.opentrv.hdd;

import java.util.Calendar;
import java.util.Collection;
import java.util.Collections;
import java.util.Map.Entry;
import java.util.SortedMap;
import java.util.SortedSet;
import java.util.TimeZone;
import java.util.TreeSet;


/**Utility HDD methods. */
public final class Util
    {
    private Util() { /* prevent instance creation */ }

    /**Default (UK) HDD base temperature in C. */
    public static final float DEFAULT_HDD_BASE_TEMP_C = 15.5f;

    /**Default conversion factor (for UK) gas m^3 readings to kWh. */
    public static final float DEFAULT_GAS_M3_TO_KWH = 11.1f;

    /**Create Date from (non-null) YYYYMMDD Integer key; never null. */
    public static Calendar dateFromKey(final Integer k)
        {
        if(null == k) { throw new IllegalArgumentException(); }
        final int ki = k.intValue();
        if(ki < 10000000) { throw new IllegalArgumentException(k.toString()); }
        if(ki > 99990000) { throw new IllegalArgumentException(k.toString()); }
        final int year = ki / 10000;
        final int month = ((ki / 100) % 100) - 1; // Zero-based.
        if((month < 0) || (month >= 12)) { throw new IllegalArgumentException(); }
        final int day = ki % 100;
        if((day < 1) || (day > 31)) { throw new IllegalArgumentException(); }
        final Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        cal.set(year, month, day);
        return(cal);
        }

    /**Create Integer YYYYMMDD key from Calendar date; never null. */
    public static Integer keyFromDate(final Calendar cal)
        {
        if(null == cal) { throw new IllegalArgumentException(); }
        final int year = cal.get(Calendar.YEAR);
        if((year < 1000) || (year > 9999)) { throw new IllegalArgumentException(); }
        final int month = cal.get(Calendar.MONTH) + 1;
        if((month < 1) || (month > 12)) { throw new IllegalArgumentException(); }
        final int day = cal.get(Calendar.DAY_OF_MONTH);
        if((day < 1) || (day > 31)) { throw new IllegalArgumentException(); }
        final int ki = (year * 10000) + (month * 100) + day;
        return(ki);
        }

    /**Returns previous YYYYMMDD date. */
    public static Integer getPreviousKeyDate(final Integer k)
        {
        if(null == k) { throw new IllegalArgumentException(); }
        final int ki = k.intValue();
        if(ki < 10000000) { throw new IllegalArgumentException(k.toString()); }
        if(ki > 99990000) { throw new IllegalArgumentException(k.toString()); }
        final int day = ki % 100;
        if((day < 1) || (day > 31)) { throw new IllegalArgumentException(); }
        // Optimise for days unconditionally within the same month.
        if((day > 1) && (day < 29)) { return(ki - 1); }
        final int year = ki / 10000;
        final int month = ((ki / 100) % 100) - 1; // Zero-based.
        if((month < 0) || (month >= 12)) { throw new IllegalArgumentException(); }
        final Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        // Use the calendar...
        cal.set(year, month, day);
        cal.add(Calendar.DAY_OF_MONTH, -1);
        return(keyFromDate(cal));
        }

    public static Calendar getMidDate(final int end, final int start)
        {
        final Calendar cS = dateFromKey(start);
        final Calendar cE = dateFromKey(end);
        final Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
        cal.setTimeInMillis(((cS.getTimeInMillis() + cE.getTimeInMillis()) / 2));
        return(cal);
        }

    /**Split CSV (non-null) line into fields efficiently; never null. */
    public static final String[] splitCSVLine(final String line)
        { return(line.split(",")); }

    /**Combines meter readings (consumption) and HDD data to generate meter ticks per HDD immutable data set; never null.
     * The result will be at least one smaller than the smaller of
     * the set of meter readings and the HDD readings.
     *
     * @param meterReadings  meter readings indexed by YYYYMMDD date; never null nor empty
     * @param hdd  source of heating-degree-day data indexed by YYYYMMDD date; never null nor empty
     * @param nightRead  if true, assume that readings are taken in the evening or at night,
     *     thus the HDD value for the final day (and not for the first) should be included
     * @return
     */
    public static SortedSet<ConsumptionHDDTuple> combineMeterReadingsWithHDD(
            final SortedMap<Integer, Double> meterReadings,
            final ContinuousDailyHDD hdd,
            final boolean nightRead)
        {
        if(null == meterReadings) { throw new IllegalArgumentException(); }
        if(meterReadings.isEmpty()) { throw new IllegalArgumentException(); }
        if(null == hdd) { throw new IllegalArgumentException(); }
        final SortedMap<Integer, Float> hddMap = hdd.getMap();
        if(hddMap.isEmpty()) { throw new IllegalArgumentException(); }

        final SortedSet<ConsumptionHDDTuple> result = new TreeSet<>();

        // HDD data must more than span the meter readings.
        if(meterReadings.firstKey() < hddMap.firstKey()) { throw new IllegalArgumentException("HDD data missing for start of meter readings"); }
        if(meterReadings.lastKey() > hddMap.lastKey()) { throw new IllegalArgumentException("HDD data missing for end of meter readings"); }

        // Compute HDD sum in each interval between meter readings.
        Integer prevKey = null;
        for(final Integer readingKey : meterReadings.keySet())
            {
            if(null != prevKey)
                {
                final double consumption = meterReadings.get(readingKey) - meterReadings.get(prevKey);
                final int intervalDays = daysBetweenDateKeys(prevKey, readingKey);
//System.out.println("Reading interval " + prevKey + " to " + readingKey + " ("+intervalDays+"d)," + " last day " + (nightRead ? "included" : "excluded"));
                // Sum the subset of HDD datums that apply to the meter-reading interval.
                float hddSum = 0f;
                for(final Entry<Integer, Float> e : hddMap.tailMap(prevKey).entrySet())
                    {
                    final int ek = e.getKey().intValue();
                    final int rk = readingKey.intValue();
                    if(nightRead && (ek == prevKey.intValue())) { continue; } // Exclude initial day for night reads.
                    if((!nightRead) && (ek >= rk)) { break; } // Exclude final day for morning reads.
                    if(ek > rk) { break; }
                    hddSum += e.getValue();
                    }
                result.add(new ConsumptionHDDTuple(prevKey, readingKey, consumption, hddSum, intervalDays));
                }
            prevKey = readingKey;
            }

        return(Collections.unmodifiableSortedSet(result));
        }

    /**Combines daily interval energy readings and daily HDD data to generate energy use per HDD immutable data set; never null.
     * The output size should be the same as the number of interval readings,
     * though HDD data must at least cover/include all the energy interval reading days.
     *
     * @param intervalReadings  interval energy readings indexed by YYYYMMDD date; never null nor empty
     * @param hdd  source of heating-degree-day data indexed by YYYYMMDD date; never null nor empty
     */
    public static SortedSet<ConsumptionHDDTuple> combineDailyIntervalReadingsWithHDD(
            final SortedMap<Integer, Float> intervalReadings,
            final ContinuousDailyHDD hdd)
        {
        if(null == intervalReadings) { throw new IllegalArgumentException(); }
        if(intervalReadings.isEmpty()) { throw new IllegalArgumentException(); }
        if(null == hdd) { throw new IllegalArgumentException(); }
        final SortedMap<Integer, Float> hddMap = hdd.getMap();
        if(hddMap.isEmpty()) { throw new IllegalArgumentException(); }

        final SortedSet<ConsumptionHDDTuple> result = new TreeSet<>();

        // HDD data must more than span the meter readings.
        if(intervalReadings.firstKey() < hddMap.firstKey()) { throw new IllegalArgumentException("HDD data missing for start of interval energy readings @ " + intervalReadings.firstKey()); }
        if(intervalReadings.lastKey() > hddMap.lastKey()) { throw new IllegalArgumentException("HDD data missing for end of interval energy readings @ " + intervalReadings.lastKey()); }

        for(final Integer readingKey : intervalReadings.keySet())
            {
            final Float hddToday = hddMap.get(readingKey);
            if(null == hddToday) { throw new IllegalArgumentException("HDD data missing for interval energy reading @ "+readingKey); }
            result.add(new ConsumptionHDDTuple(getPreviousKeyDate(readingKey), readingKey, intervalReadings.get(readingKey), hddToday, 1));
            }

        return(Collections.unmodifiableSortedSet(result));
        }

    /**Compute the number of days between the first YYYYMMDD date and the second/later one; non-negative. */
    public static int daysBetweenDateKeys(final int first, final int second)
        {
        if(second < first) { throw new IllegalArgumentException(); }
        if(first == second) { return(0); }
        final Calendar c1 = dateFromKey(first);
        final Calendar c2 = dateFromKey(second);
        // Round the days to allow for DST changes.
        final int d = (int) ((((c2.getTimeInMillis() - c1.getTimeInMillis()) / (12 * 60 * 60 * 1000)) + 1) / 2);
        return(d);
        }

    /**Immutable store of energy efficiency metrics energy/HDD (slope), baseline (intercept) and R^2.
     * Values all stored as (non-NaN, non-Inf) float values
     * since that already represents more precision that is likely available from the data!
     */
    public static final class HDDMetrics
        {
        public final float slopeEnergyPerHDD;
        public final float interceptBaseline;
        public final float rsqFit;
        /**Count of points; strictly positive. */
        public final int n;
        public HDDMetrics(final float slopeEnergyPerHDD, final float interceptBaseline, final float rsqFit, final int n)
            {
            if(n <= 0) { throw new IllegalArgumentException(); }
            if(Float.isNaN(slopeEnergyPerHDD) || Float.isInfinite(slopeEnergyPerHDD)) { throw new IllegalArgumentException("slopeEnergyPerHDD: "+slopeEnergyPerHDD); }
            if(Float.isNaN(interceptBaseline) || Float.isInfinite(interceptBaseline)) { throw new IllegalArgumentException("interceptBaseline: "+interceptBaseline); }
            if(Float.isNaN(rsqFit) || Float.isInfinite(rsqFit)) { throw new IllegalArgumentException("rsqFit: "+ rsqFit); }
            this.slopeEnergyPerHDD = slopeEnergyPerHDD;
            this.interceptBaseline = interceptBaseline;
            this.rsqFit = rsqFit;
            this.n = n;
            }
        @Override public String toString()
            { return("HDDMetrics [slope="+slopeEnergyPerHDD+",baseload="+interceptBaseline+",R^2="+rsqFit+",n="+n+"]"); }
        /**Produce simple CVS format "slope,baseload,R^2,n" eg "1.2,3.5,0.73,156"; no leading/terminating comma, never null. */
        public String toCSV()
            { return(slopeEnergyPerHDD+","+interceptBaseline+","+rsqFit+","+n); }
        /**Produce header for simple CSV format; no leading/terminating comma, never null. */
        public static String headerCSV() { return("\"slope energy/HDD\",\"baseload energy\",\"R^2\",\"n\""); }
        }

    /**Compute energy efficiency metrics based on combined energy use and HDD values; never null nor empty nor singleton. */
    public static final HDDMetrics computeHDDMetrics(final Collection<ConsumptionHDDTuple> data)
        {
        if(null == data) { throw new IllegalArgumentException(); }
        if(data.size() < 2) { throw new IllegalArgumentException(); }

        // X = HDD (independent variable), Y = consumption.
        // Pass 1: compute xbar and ybar (means).
        double sumx = 0;
        double sumy = 0;
//        double sumxsq = 0;
        final int n = data.size();
        for(final ConsumptionHDDTuple datum : data)
            {
            sumx += datum.hdd;
//            sumxsq += datum.hdd * datum.hdd;
            sumy += datum.consumption;
            }
        final double xbar = sumx / n;
        final double ybar = sumy / n;

        // Pass 2: summary stats.
        double xxbar = 0;
        double xybar = 0;
        double yybar = 0;
        for(final ConsumptionHDDTuple datum : data)
            {
            final double hdiff = datum.hdd - xbar;
            final double cdiff = datum.consumption - ybar;
            xxbar += hdiff * hdiff;
            xybar += hdiff * cdiff;
            yybar += cdiff * cdiff;
            }
        final double slope = xybar / xxbar;
        final double intercept = ybar - (slope * xbar);

        double ssr = 0; // Regression sum of squares.
        for(final ConsumptionHDDTuple datum : data)
            {
            final double fit = (slope * datum.hdd) + intercept;
            final double fydiff = fit - ybar;
            ssr += fydiff * fydiff;
            }
        final double rsqFit = ssr / yybar;
//System.out.println(data);
//System.out.println("slope="+slope+ ", intercept="+intercept+ ", rsqFit="+rsqFit+ ", n="+n);

        return(new HDDMetrics((float) slope, (float) intercept, (float) rsqFit, n));
        }

    /**Normalise energy units (multiplying by supplied factor) and to single days; never null. */
    public static SortedSet<ConsumptionHDDTuple> normalisedMeterReadingsWithHDD(
            final SortedSet<ConsumptionHDDTuple> readingsWithHDD,
            final float energyUnitMultiplier)
        {
        if(null == readingsWithHDD) { throw new IllegalArgumentException(); }
        final SortedSet<ConsumptionHDDTuple> result = new TreeSet<>();
        for(final ConsumptionHDDTuple datum : readingsWithHDD)
            {
            final int days = datum.hddDays;
            result.add(new ConsumptionHDDTuple(
                datum.prevReadingDateYYYYMMDD,
                datum.endReadingDateYYYYMMDD,
                (datum.consumption * energyUnitMultiplier) / days,
                datum.hdd / days,
                1));
            }
        return(Collections.unmodifiableSortedSet(result));
        }

    /**Find the HDD data set with base temperature closest to that specified from the given collection; never null.
     * @param hdds  HDD data sets for same location, differing in base temperatures; never null not empty
     * @param targetBaseTemperature  desired base temperature; never NaN nor InF
     * @return  closest available HDD data set; never null
     */
    public static ContinuousDailyHDD findHDDWithClosestBaseTemp(
            final Collection<ContinuousDailyHDD> hdds,
            final float targetBaseTemperature)
        {
        if((null == hdds) || hdds.isEmpty()) { throw new IllegalArgumentException(); }
        if(Float.isNaN(targetBaseTemperature) || Float.isInfinite(targetBaseTemperature)) { throw new IllegalArgumentException(); }
        // If only one available HDD data set then return it immediately.
        if(1 == hdds.size()) { return(hdds.iterator().next()); }
        // Best so far and diff for desired.
        ContinuousDailyHDD best = null;
        float bestDiff = 0;
        for(final ContinuousDailyHDD hdd : hdds)
            {
            final float diff = Math.abs(targetBaseTemperature - hdd.getBaseTemperatureAsFloat());
            if((null == best) || (diff < bestDiff))
                {
                best = hdd;
                bestDiff = diff;
                }
            }
        return(best);
        }

    /**Description of optimal fit and parameters used to achieve it. */
    public static final class OptimumFit
        {
        /**Optimal fit result; never null. */
        public final HDDMetrics bestFit;
        /**True if reads appear to be evening/night. */
        public final boolean eveningReads;
        /**HDD base temperature for best fit (C); never NaN nor Inf. */
        public final float hddBaseTempC;
        /**Construct an instance. */
        public OptimumFit(
                final HDDMetrics bestFit,
                final boolean eveningReads,
                final float hddBaseTempC)
            {
            if(null == bestFit) { throw new IllegalArgumentException(); }
            if(Float.isNaN(hddBaseTempC) || Float.isInfinite(hddBaseTempC)) { throw new IllegalArgumentException(); }
            this.bestFit = bestFit;
            this.eveningReads = eveningReads;
            this.hddBaseTempC = hddBaseTempC;
            }
        /**Human-readable summary. */
        @Override
        public String toString()
            {
            return("OptimumFit [bestFit=" + bestFit + ", eveningReads="
                    + eveningReads + ", hddBaseTempC=" + hddBaseTempC + "]");
            }
        }

    /**Find the best (highest) R-squared fit for a set of readings for combinations of base temperature and reading time; may be null data does not allow any fit.
     * To avoid undue bias due to sample time window,
     * the HDD sets should all cover the same dates.
     */
    public static OptimumFit findOptimumR2(final Collection<ContinuousDailyHDD> hdds, final SortedMap<Integer, Double> rawMeterReadings, final float energyUnitMultiplier)
        {
        OptimumFit result = null;
        for(final ContinuousDailyHDD hdd : hdds)
            {
            final SortedMap<Integer, Double> trimmedMeterReadings = rawMeterReadings.
                    tailMap(Math.max(hdd.getMap().firstKey(), rawMeterReadings.firstKey())).
                    headMap(Math.min(hdd.getMap().lastKey(), rawMeterReadings.lastKey()));
            for(final boolean evening : new boolean[]{false, true})
                {
                try {
                    final SortedSet<ConsumptionHDDTuple> readingsWithHDD = Util.combineMeterReadingsWithHDD(trimmedMeterReadings, hdd, evening);
                    final SortedSet<ConsumptionHDDTuple> normalisedMeterReadingsWithHDD = Util.normalisedMeterReadingsWithHDD(readingsWithHDD, energyUnitMultiplier);
                    final HDDMetrics metrics = computeHDDMetrics(normalisedMeterReadingsWithHDD);
                    final OptimumFit putativeResult = new OptimumFit(metrics, evening, hdd.getBaseTemperatureAsFloat());
//                    System.out.println(putativeResult);
                    if((null == result) || (putativeResult.bestFit.rsqFit > result.bestFit.rsqFit))
                        { result = putativeResult; }
                    }
                // Quietly ignore cases where line fitting is not possible.
                catch(final IllegalArgumentException e)
                    { continue; }
                }
            }
        return(result);
        }
    }
