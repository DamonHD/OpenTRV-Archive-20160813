package uk.org.opentrv.hdd;

/**Immutable tuple of consumption (metered energy use) and HDD (over specified period in whole days).
 * Extensible so that extra information can be tagged on by sub-classing.
 * <p>
 * Note that whether the HDD for the end date should be included (implying evening/night reading),
 * or up to the day before (morning reading) has to be taken before this datum is constructed.
 * <p>
 * Sort order is ascending by the end reading date alone;
 * compareTo(), equals() and hashCode() are consistent with one another.
 */
public class ConsumptionHDDTuple implements Comparable<ConsumptionHDDTuple>
    {
    /**Previous meter reading date as YYYYMMDD. */
    public final int prevReadingDateYYYYMMDD;
    /**Terminating meter reading date as YYYYMMDD. */
    public final int endReadingDateYYYYMMDD;
    /**Consumption in specified period/interval of arbitrary energy units, eg gas m^3; never negative, NaN nor infinite. */
    public final double consumption;
    /**Heating degree days in specified period/interval (C); never negative, NaN nor infinite. */
    public final double hdd;
    /**Number of days for over which hdd is summed; strictly positive. */
    public final int hddDays;
    /**Create an instance. */
    public ConsumptionHDDTuple(final int prevReadingDateYYYYMMDD,
                               final int endReadingDateYYYYMMDD,
                               final double consumption,
                               final double hdd, final int hddDays)
        {
        if((consumption < 0) || Double.isNaN(consumption) || Double.isInfinite(consumption)) { throw new IllegalArgumentException(); }
        if((hdd < 0) || Double.isNaN(hdd) || Double.isInfinite(hdd)) { throw new IllegalArgumentException(); }
        // TODO: full validation of dates.
        if((prevReadingDateYYYYMMDD < 10000001) || (prevReadingDateYYYYMMDD > 99991231)) { throw new IllegalArgumentException(); }
        if((endReadingDateYYYYMMDD < 10000001) || (endReadingDateYYYYMMDD > 99991231)) { throw new IllegalArgumentException(); }
        if(prevReadingDateYYYYMMDD >= endReadingDateYYYYMMDD) { throw new IllegalArgumentException(); }
        if(hddDays < 0) { throw new IllegalArgumentException(); }
        this.consumption = consumption;
        this.hdd = hdd;
        this.prevReadingDateYYYYMMDD = prevReadingDateYYYYMMDD;
        this.endReadingDateYYYYMMDD = endReadingDateYYYYMMDD;
        this.hddDays = hddDays;
        }
    /**Make a date comparison key only. */
    public ConsumptionHDDTuple(final int endReadingDateYYYYMMDD)
        {
        // TODO: full validation of endReadingDateYYYYMMDD.
        if((endReadingDateYYYYMMDD < 10000001) || (endReadingDateYYYYMMDD > 99991231)) { throw new IllegalArgumentException(); }
        this.prevReadingDateYYYYMMDD = endReadingDateYYYYMMDD;
        this.endReadingDateYYYYMMDD = endReadingDateYYYYMMDD;
        this.consumption = 0;
        this.hdd = 0;
        this.hddDays = 1;
        }

    /**Comparison is total on the end reading date alone and is consistent with equals() and hashCode(). */
    @Override
    public int compareTo(final ConsumptionHDDTuple o)
        {
        if(null == o) { throw new IllegalArgumentException(); }
        return(endReadingDateYYYYMMDD - o.endReadingDateYYYYMMDD);
        }
    /**Hash depends only on end reading date and is consistent with equals() and compareTo(). */
    @Override
    public int hashCode() { return(endReadingDateYYYYMMDD); }
    /**Equality depends only on end reading date and is consistent with hashCode() and compareTo(). */
    @Override
    public boolean equals(final Object obj)
        {
        if(this == obj) { return(true); }
        if(obj == null) { return(false); }
        if(getClass() != obj.getClass()) { return(false); }
        final ConsumptionHDDTuple other = (ConsumptionHDDTuple) obj;
        return(endReadingDateYYYYMMDD == other.endReadingDateYYYYMMDD);
        }

    @Override
    public String toString()
        {
        return "ConsumptionHDDTuple [endReadingDateYYYYMMDD="
                + endReadingDateYYYYMMDD + ", consumption=" + consumption
                + ", hdd=" + hdd + ", intervalDays=" + hddDays + "]";
        }
    }