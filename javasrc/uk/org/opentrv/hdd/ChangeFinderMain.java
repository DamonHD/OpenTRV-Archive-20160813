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


/**Looks for changes in heating efficiency caused by fabric and heating system changes, good or bad.
 * The basic aim is to look for a change in slope of kWh/HDD over windows of (say) 1 month,
 * vs a whole year, though changes in R may also be interesting.
 * <p>
 * See: http://en.wikipedia.org/wiki/Simple_linear_regression
 */
public final class ChangeFinderMain
    {
    /**Default multiplier, for m^3 of gas to kWh, ie from gas bills to get kWh/HDD; strictly positive. */
    public static final float DEFAULT_MULTIPLIER = 11.1f;

    /**Default HDD base temperature, degrees Celsius. */
    public static final float DEFAULT_BASE_C = 15.5f;

    /**
     * @param args [options] MeterReadings.csv HDDfile.csv
     *
     * Options:
     * <ul>
     * <li>-multiplier=meterunittokWhmultiplier</li>
     * <li>-baseC=HDDbase</li>
     * </ul>
     */
    public static void main(final String[] args)
        {
        // TODO Auto-generated method stub

        }

    }
