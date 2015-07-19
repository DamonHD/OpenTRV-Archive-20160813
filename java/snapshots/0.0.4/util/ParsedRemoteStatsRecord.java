package uk.org.opentrv.comms.util;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**Parsed representation of '@' remote stats record in various forms.
 * Should cope with various levels of detail.
 * <p>
 * Immutable, thread-safe
 */
public final class ParsedRemoteStatsRecord
    {
    /**Identifier/key for 'ID' record. */
    public static final char KEY_ID = '@';
    /**Identifier/key for temperature record. */
    public static final char KEY_TEMPERATURE = 'T';
    /**Identifier/key for power(-low) record. */
    public static final char KEY_POWER = 'P';

    /**Time record was constructed. */
    public final long constructionTime = System.currentTimeMillis();

    /**Non-null, non-empty 'raw' form as received from OpenTRV unit.
     * Example: <tt>@D49;T19C7</tt>.
     */
    public final String raw;

    /**Map (immutable) from key to record section (omitting leading key char); never empty. */
    public final Map<Character, String> sectionsByKey;

    /**Extracted ID; never null. */
    public final String ID;

    /**Create an instance and parse it, possibly eagerly or lazily. */
    public ParsedRemoteStatsRecord(final String raw)
        {
        if((null == raw) || !raw.startsWith("@")) { throw new IllegalArgumentException(); }
        this.raw = raw;
        final Map<Character, String> s = new HashMap<>();
        for(final String section : raw.split(";"))
            {
            final String st = section.trim();
            if("".equals(st)) { throw new IllegalArgumentException("empty section"); }
            final Character k = Character.valueOf(st.charAt(0));
            if(s.containsKey(k)) { throw new IllegalArgumentException("duplicate section: " + k); }
            s.put(k, st.substring(1));
            }
        sectionsByKey = Collections.unmodifiableMap(s);
        ID = s.get(KEY_ID);
        assert(null != ID);
        }


    /**Parse temperature from float of the form ddCh (dd is decimal, h is hex), */
    public static float parseTemperatureFromDDCH(final String rawTempValue)
        {
        final int rtlen = rawTempValue.length();
        final float temp = Integer.parseInt(rawTempValue.substring(0, rtlen-2), 10) +
                (Integer.parseInt(rawTempValue.substring(rtlen-1), 16) / 16f);
        return(temp);
        }

    /**Get temperature as Float, else return null if none. */
    public Float getTemperature()
        {
        final String t = sectionsByKey.get(KEY_TEMPERATURE);
        if(null == t) { return(null); }
        return(parseTemperatureFromDDCH(t));
        }
    }