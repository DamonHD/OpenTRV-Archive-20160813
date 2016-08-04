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

import java.util.SortedMap;

/**Continuous (ie no-missing-days) map of HDD values by day over an interval.
 * Implementations should generally be immutable.
 * <p>
 * The notion of day may be based on a local time zone,
 * eg some days may be different lengths at DST switches.
 */
public abstract class ContinuousDailyHDD implements Comparable<ContinuousDailyHDD>
    {
    /**Get base temperature for this data set as float; never Inf, may be NaN if unknown or not constant. */
    public abstract float getBaseTemperatureAsFloat();

    /**Get immutable map from date as YYYYMMDD integer to HDD value as Float; never null. */
    public abstract SortedMap<Integer, Float> getMap();

    /**Ordering is strictly by base temperature and is (largely) consistent with hashCode() and equals(). */
    @Override
    public final int compareTo(final ContinuousDailyHDD o)
        {
        final float f = getBaseTemperatureAsFloat();
        final float of = o.getBaseTemperatureAsFloat();
        if(f < of) { return(-1); }
        if(f > of) { return(+1); }
        return(0);
        }

    /**Hash is by raw float bits and is (largely) consistent with compareTo() and equals(). */
    @Override
    public final int hashCode()
        { return(Float.floatToIntBits(getBaseTemperatureAsFloat())); }

    /**Hash is by raw float bits and is (largely) consistent with hashCode() and compareTo(). */
    @Override
    public final boolean equals(final Object obj)
        {
        return((obj instanceof Float) &&
            (Float.floatToIntBits(((ContinuousDailyHDD)obj).getBaseTemperatureAsFloat()) == Float.floatToIntBits(getBaseTemperatureAsFloat())));
        }

    }
