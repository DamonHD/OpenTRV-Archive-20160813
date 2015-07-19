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

Author(s) / Copyright (s): Damon Hart-Davis 2015
*/
package uk.org.opentrv.comms.statshandlers.builtin.twitter;

/**Simple immutable configuration for a single pre-created Twitter channel.
 * Contains safe defaults.
 */
public final class SingleTwitterChannelConfig
    {
    /**Default minimum minutes between tweets on this channel; strictly positive. */
    public static final int DEFAULT_MINIMUM_MESSAGE_INTERVAL_M = 15;

    /**Minimum minutes between tweets on this channel; strictly positive. */
    public final int minimumMessageIntervalMinutes = DEFAULT_MINIMUM_MESSAGE_INTERVAL_M;

    /**Default Twitter handle prefix (hex ID will be appended); non-null and non-empty. */
    public static final String DEFAULT_HANDLE_PREFIX = "OpenTRV_S";

    /**Full Twitter handle ending with hex ID; never null nor empty. */
    public final String fullHandle;

    /**Hex ID (lower case, 2--8 digits) for leaf whose data is to be forwarded to Twitter. */
    public final String hexID;

    /**Create with specified ID for filtering and Twitter handle generation.*/
    public SingleTwitterChannelConfig(final String hexID)
        {
        if((null == hexID)) { throw new IllegalArgumentException(); }
        final int hil = hexID.length();
        if((hil < 1) || (hil > 8)) { throw new IllegalArgumentException(); }
        final String lchi = hexID.toLowerCase();
        for(int i = hil; --i >= 0; )
            {
            final char c = lchi.charAt(i);
            if((c >= '0') && (c <= '9')) { continue; }
            if((c >= 'a') && (c <= 'z')) { continue; }
            throw new IllegalArgumentException();
            }
        this.hexID = lchi;
        this.fullHandle = DEFAULT_HANDLE_PREFIX + lchi;
        }
    }
