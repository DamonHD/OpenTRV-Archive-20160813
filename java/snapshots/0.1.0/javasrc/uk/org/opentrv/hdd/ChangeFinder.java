package uk.org.opentrv.hdd;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.SortedMap;
import java.util.SortedSet;
import java.util.TreeMap;
import java.util.TreeSet;

import uk.org.opentrv.hdd.Util.HDDMetrics;
import uk.org.opentrv.hdd.Util.OptimumFit;

/**Analyse a data set of HDD values and meter readings looking for efficiency/baseload/other inflections.
 * Can also spit out data for analysis by other tools such as GNU plot.
 */
public final class ChangeFinder
    {
    /**Construct with one or more sets of HDD data (eg at different base temps), with meter readings and scale factor to kWh from meter units.
     */
    public ChangeFinder(final SortedSet<ContinuousDailyHDD> hdds,
                        final SortedMap<Integer, Double> rawMeterReadings,
                        final float energyUnitMultiplier)
        {
        if((null == hdds) || hdds.isEmpty()) { throw new IllegalArgumentException(); }
        if((null == rawMeterReadings) || rawMeterReadings.isEmpty()) { throw new IllegalArgumentException(); }
        if((0 == energyUnitMultiplier) || Float.isNaN(energyUnitMultiplier) || Float.isInfinite(energyUnitMultiplier)) { throw new IllegalArgumentException(); }

        // Take defensive copies where necessary to ensure immutability and no surprises!
        this.energyUnitMultiplier = energyUnitMultiplier;
        this.hdds = new TreeSet<>(hdds);
        this.rawMeterReadings = new TreeMap<>(rawMeterReadings);
        }

    /**Heating degree data sets for different base temperatures; never null nor empty. */
    private final SortedSet<ContinuousDailyHDD> hdds;
    /**Raw meter readings by date; never null nor empty. */
    private final SortedMap<Integer, Double> rawMeterReadings;
    /**Energy multiplier from meter units to kWh. */
    private final float energyUnitMultiplier;

    /**Default base temperature (C). */
    public static final float DEFAULT_BASE_TEMP = Util.DEFAULT_HDD_BASE_TEMP_C;

    /**Default minimum data points acceptable in a regression sample; strictly positive. */
    public static final int DEFAULT_MIN_REGRESSION_DATA_POINTS = 4;
    /**Default minimum R-squared value for results to be considered reliable/consistent. */
    public static final float DEFAULT_MIN_RSQUARED = 0.5f;

    /**Default window sizes (win weeks, ascending) to track heating efficiency over; never null nor empty.
     * The first/smallest of these is the primary one for
     * confirming the effect of interventions (or technical problems).
     */
    public static final List<Integer> DEFAULT_WINDOW_SIZES_W = Collections.unmodifiableList(Arrays.asList(new Integer[]{
            8, 26, 52
        }));

    /**True if the month (range [1,12]) specified is in the typical (UK) heating season. */
    public static boolean isTypicallyUKHeatingSeasonMonth(final int month)
        {
        // Page 4: https://www.gov.uk/government/uploads/system/uploads/attachment_data/file/65954/chapter_3_domestic_factsheet.pdf
        // "... the main heating season (January to March and October to December)."
        final boolean isHeatingSeasonEndMonth = (month <= 3) || (month >= 10);
        return(isHeatingSeasonEndMonth);
        }

    /**Get basic metrics over entire data set with some common defaults.
     * Eg use default base temperature (15.5C) if possible, assume evening/night readings.
     */
    public HDDMetrics getBasicFullDataMetrics()
        {
        // Choose closest HDD available to default.
        final ContinuousDailyHDD hdd = Util.findHDDWithClosestBaseTemp(hdds, DEFAULT_BASE_TEMP);
        final SortedMap<Integer, Double> trimmedMeterReadings = rawMeterReadings.tailMap(hdd.getMap().firstKey()).headMap(hdd.getMap().lastKey());
        final SortedSet<ConsumptionHDDTuple> readingsWithHDD = Util.combineMeterReadingsWithHDD(trimmedMeterReadings, hdd, true);
        final SortedSet<ConsumptionHDDTuple> normalisedMeterReadingsWithHDD = Util.normalisedMeterReadingsWithHDD(readingsWithHDD, energyUnitMultiplier);
        return(Util.computeHDDMetrics(normalisedMeterReadingsWithHDD));
        }

    /**Get best-fit metrics over entire data set given available HDD range, etc. */
    public Util.OptimumFit getBestFullDataFit()
        {
        return(Util.findOptimumR2(hdds, rawMeterReadings, energyUnitMultiplier));
        }

    /**Get best-fit metrics by calendar year over entire data set given available HDD range, etc. */
    public SortedMap<Integer,Util.OptimumFit> getBestByCalendarYearFit()
        {
        // Estimate first and last years to sample.
        final int estFirstYear = Math.max(rawMeterReadings.firstKey(), hdds.first().getMap().firstKey()) / 1_00_00;
        final int estLastYear = Math.min(rawMeterReadings.lastKey(), hdds.first().getMap().lastKey()) / 1_00_00;
//        System.out.println("est " + estFirstYear + "--"  + estLastYear);
        final SortedMap<Integer,Util.OptimumFit> result = new TreeMap<>();
        for(int year = estFirstYear; year <= estLastYear; ++year)
            {
            final SortedMap<Integer, Double> filteredMeterReadings = rawMeterReadings.tailMap((year*1_00_00) + 101).headMap(((year+1)*1_00_00) + 101);
            final OptimumFit optimumR2 = Util.findOptimumR2(hdds, filteredMeterReadings, energyUnitMultiplier);
//            System.out.println("Year " + year + " optimum " + optimumR2);
            result.put(year, optimumR2);
            }
        return(Collections.unmodifiableSortedMap(result));
        }

    public static class EfficiencyChangeEvent
        {
        /**Approximate start and end dates in YYYYMMDD format. */
        public final int start, end;
        /**Reason. */
        public final List<String> reasons;
        /**Prior and following usable efficiency results; can be null. */
        public final HDDMetrics preEff, postEff;

        /**Get mid-point of interval near where event probably happened; never null. */
        public Calendar midPoint() { return(Util.getMidDate(start, end)); }

        /**Get approximate duration of 'event' in weeks. */
        public int durationWeeks()
            {
            final Calendar cS = Util.dateFromKey(start);
            final Calendar cE = Util.dateFromKey(end);
            return((int) ((cE.getTimeInMillis() - cS.getTimeInMillis()) / (7 * 24 * 3600 * 1000L)));
            }

        /**Create an instance. */
        public EfficiencyChangeEvent(final int start, final int end, final HDDMetrics preEff, final HDDMetrics postEff, final List<String> reasons)
            {
            // TODO: argument validation.
            this.start = start;
            this.end = end;
            if(start > end) { throw new IllegalArgumentException(); }
            this.reasons = (null == reasons) ? null : Collections.unmodifiableList(new ArrayList<>(reasons));
            this.preEff = preEff;
            this.postEff = postEff;
            }

        /**Human-readable raw summary. */
        @Override
        public String toString()
            {
            final String before = (null == preEff) ? "unknown" : String.valueOf(preEff.slopeEnergyPerHDD);
            final String after = (null == postEff) ? "unknown" : String.valueOf(postEff.slopeEnergyPerHDD);
            return("EfficiencyChangeEvent around "+ Util.keyFromDate(midPoint()) + " max "+durationWeeks()+" weeks, slope before "+before+" and after "+after + ": " + reasons);
            }
        }

    /**Produce ordered list of possible heating-efficiency change events/intervals; never null but may be empty.
     * This is based on intervals where the shortest inspection window
     * gives results indicating poor fit or similar.
     *
     * @param applyUKFilter  if true, apply some filtering specific to UK
     */
    public List<EfficiencyChangeEvent> getEfficiencyChangeEvents(final boolean applyUKFilter)
        {
        final ArrayList<EfficiencyChangeEvent> result = new ArrayList<>();

        // Compute initial pass over all the available data.
        final Util.OptimumFit fullMetrics = getBestFullDataFit();
        final ContinuousDailyHDD hdd = Util.findHDDWithClosestBaseTemp(hdds, fullMetrics.hddBaseTempC);
        final SortedMap<Integer, Double> trimmedMeterReadings = rawMeterReadings.tailMap(hdd.getMap().firstKey()).headMap(hdd.getMap().lastKey());
        final SortedSet<ConsumptionHDDTuple> readingsWithHDD = Util.combineMeterReadingsWithHDD(trimmedMeterReadings, hdd, fullMetrics.eveningReads);
        final SortedSet<ConsumptionHDDTuple> normalisedMeterReadingsWithHDD = Util.normalisedMeterReadingsWithHDD(readingsWithHDD, energyUnitMultiplier);

        // Use shortest window while hunting for efficiency inflections.
        final int weeksWindow = DEFAULT_WINDOW_SIZES_W.get(0);

        HDDMetrics lastGood = null; // Last good metric value computed.
        int lastGoodMidPoint = 0; // Last good metric value mid-point date.
        for(final ConsumptionHDDTuple datum : normalisedMeterReadingsWithHDD)
            {
            // Line results up by end date.
            final int endTarget = datum.endReadingDateYYYYMMDD;
            final Calendar tmpC = Util.dateFromKey(endTarget);
            tmpC.add(Calendar.WEEK_OF_YEAR, -weeksWindow);
            final int startTarget = Util.keyFromDate(tmpC);

            final ConsumptionHDDTuple startTargetKey = new ConsumptionHDDTuple(startTarget);
            final ConsumptionHDDTuple endTargetKey =  new ConsumptionHDDTuple(endTarget);
            final SortedSet<ConsumptionHDDTuple> data = normalisedMeterReadingsWithHDD;
            final SortedSet<ConsumptionHDDTuple> dataFiltered = data.tailSet(startTargetKey).headSet(endTargetKey);
            if(dataFiltered.size() < ChangeFinder.DEFAULT_MIN_REGRESSION_DATA_POINTS) { continue; } // Too small a data set.
            if(dataFiltered.size() <= ((3*weeksWindow)/4)) { continue; } // Too few data points compared to target window size.
            // Get actual start and end dates.
            final int start = dataFiltered.first().endReadingDateYYYYMMDD;
            final int end = dataFiltered.last().endReadingDateYYYYMMDD;
//            if(isHeatingSeasonEndMonth && (0 == w)) { ++availableSmallWindows; }
//            System.out.print("data points from " + dataFiltered.first().endReadingDateYYYYMMDD + " to " + dataFiltered.last().endReadingDateYYYYMMDD + ": ");
            final HDDMetrics metrics;
            try { metrics = Util.computeHDDMetrics(dataFiltered); }
            catch(final IllegalArgumentException e)
                {
//                System.out.println("CANNOT COMPUTE");
                int eecStart = start;
                // Constrain start to be no older than previous good mid-point.
                if((result.size() > 0) && (null != result.get(result.size()-1))) { eecStart = Math.max(start, lastGoodMidPoint); }
                else if((result.size() > 1) && (null != result.get(result.size()-2))) { eecStart = Math.max(start, lastGoodMidPoint); }
                result.add(new EfficiencyChangeEvent(eecStart, end, lastGood, null, Collections.singletonList("cannot compute")));
                continue; // Poor data sets.
                }
            if((metrics.slopeEnergyPerHDD < 0) ||
//               (metrics.interceptBaseline < 0) || // Intercept value is pretty noisy...
               (metrics.rsqFit < ChangeFinder.DEFAULT_MIN_RSQUARED))
                {
//                System.out.println("BAD FIT @ n="+metrics.n);
                result.add(new EfficiencyChangeEvent(start, end, lastGood, null, Collections.singletonList("bad fit " + metrics)));
                continue;
                }
            // Note good metrics available.
            lastGood = metrics;
            lastGoodMidPoint = Util.keyFromDate(Util.getMidDate(end, start));
            // Inject into last event 'post' value and trim its end date.
            for(int i = result.size(); --i >= 0; )
                {
                final EfficiencyChangeEvent lastece = result.get(i);
                if(null == lastece) { continue; }
//                System.out.println("last ece: " + lastece);
//                if(null != lastece.postEff) { break; } // Already has postEff set.
                final EfficiencyChangeEvent lasteceUpdated = new EfficiencyChangeEvent(lastece.start, Math.min(lastece.end, lastGoodMidPoint), lastece.preEff, metrics, lastece.reasons);
                result.set(i, lasteceUpdated);
                break;
                }
            // Inject null to indicate good result (but only needed after non-null value).
            if(!result.isEmpty() && (null != result.get(result.size()-1))) { result.add(null); }
//            if(isHeatingSeasonEndMonth && (0 == w)) { ++goodSmallWindows; }
//            System.out.print(pm ? "PM readings: " : "AM readings: ");
//            System.out.println(metrics);
            }

//        for(final EfficiencyChangeEvent ece : result) { System.out.println("ECE raw: " + ece); } // Unfiltered.

        // Work backwards through the list merging overlapping items.
        for(int i = result.size(); --i > 0; )
            {
            final EfficiencyChangeEvent curr = result.get(i);
            if(null == curr)
                {
                result.remove(i); // Zap trailing null.
                continue;
                }
            final EfficiencyChangeEvent prev = result.get(i-1);
            if(null == prev) { continue; }
            if(prev.end >= curr.start)
                {
                final List<String> mergedReasons;
                if(null == prev.reasons) { mergedReasons = curr.reasons; }
                else if(null == curr.reasons) { mergedReasons = prev.reasons; }
                else
                    {
                    mergedReasons = new ArrayList<String>(prev.reasons);
                    mergedReasons.addAll(curr.reasons);
                    }
                final EfficiencyChangeEvent merged = new EfficiencyChangeEvent(prev.start, curr.end, prev.preEff, curr.postEff, mergedReasons);
                result.remove(i);
                result.set(i-1, merged);
                }
            }

        // Do some final filtering such as eliminating 'events' that would just seem likely to be summer!
        if(applyUKFilter)
            {
            for(int i = result.size(); --i >= 0; )
                {
                final EfficiencyChangeEvent curr = result.get(i);
                final int monthMid = 1 + curr.midPoint().get(Calendar.MONTH);
//System.out.println(month + "   " + curr);
                if(!isTypicallyUKHeatingSeasonMonth(monthMid))
                    {
//System.out.println("summer, zapped");
                    result.remove(i); // Zap 'summer' psuedo-event.
                    continue;
                    }
                }
            }

        for(final EfficiencyChangeEvent ece : result) { System.out.println("ECE merged/filtered: " + ece); } // Filtered.

        return(result);
        }
    }
