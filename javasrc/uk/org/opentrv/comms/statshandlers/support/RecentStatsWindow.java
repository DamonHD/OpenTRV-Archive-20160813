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
package uk.org.opentrv.comms.statshandlers.support;

import java.io.IOException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Date;
import java.util.Deque;
import java.util.List;

import org.json.simple.JSONArray;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;

/**Retains recent stats by original message and by leaf ID and field.
 * Maintains stats messages with a given maximum age compared to the newest item added,
 * which can also be regarded as auto-expiring stale data.
 * <p>
 * Expected use is embedded in another handler that does something with the collated state
 * as events come in.
 * <p>
 * Not thread-safe; intended to be used at a single end-point sink.
 */
public final class RecentStatsWindow implements StatsHandler
    {
    /**Default window size in milliseconds; strictly positive.
     * The default maximum age of the oldest item retained wrt the newest.
     * <p>
     * A default of slightly over an hour should work robustly in many cases,
     * such as allowing one dropped half-hourly meter reading,
     * and need not retain a stupid amount of data for more typical
     * every-few-minutes sensor readings.
     */
    public static final long DEFAULT_WINDOW_MS = 3700_000;

    /**Actual (maximum) window size in milliseconds; strictly positive.
     * The maximum age of the oldest item retained wrt the newest.
     */
    private final long window_ms;

    /**Get the actual (maximum) window size in milliseconds; strictly positive. */
    public long getWindowMs() { return(window_ms); }

    /**All-defaults instance. */
    public RecentStatsWindow() { this(DEFAULT_WINDOW_MS); }

    /**Create instance specifying a non-default window.
     * @param window_ms  maximum window size in milliseconds; strictly positive
     */
    public RecentStatsWindow(final long window_ms)
        {
        if(window_ms <= 0) { throw new IllegalArgumentException(); }
        this.window_ms = window_ms;
        }

    /**Ordered list of last messages inserted; never null but may be empty. */
    private final Deque<StatsMessageWithMetadata> lastMessages = new ArrayDeque<>();

    /**Accept a new stats message.
     * @param swmd  the stats message to add; never null
     * @throws IOException  out-of-order message (bad timestamp) or other issue
     */
    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd)
        throws IOException
        {
        if(null == swmd) { throw new IllegalArgumentException(); }

        final StatsMessageWithMetadata mostRecent = getMostRecentMessage();
        if((mostRecent != null) && (mostRecent.timestamp > swmd.timestamp)) { throw new IOException("misordered timestamps"); }

        // Add this new stats message to the end of the queue.
        lastMessages.add(swmd);

        // Remove all messages now too old from the front of the queue.
        final long limit = swmd.timestamp - window_ms;
        for( ; ; )
            {
            final StatsMessageWithMetadata oldest = lastMessages.peekFirst();
            if(oldest.timestamp >= limit) { break; }
            lastMessages.pop();
            }

        // TODO: clear up other cached state...
        }

    /**Returns snapshot ordered list/log of last messages inserted, idempotent; never null but may be empty. */
    public List<StatsMessageWithMetadata> getRecentStatsMessagesInOrder()
        { return(new ArrayList<>(lastMessages)); }

    /**Returns snapshot ordered list/log of last messages inserted as JSON array, idempotent; never null but may be an empty array.
     * May partially cache content or use internal state for efficiency.
     */
    public JSONArray getRecentStatsMessagesInOrderAsJSONArray()
        {
        final List<StatsMessageWithMetadata> log = getRecentStatsMessagesInOrder();
        final JSONArray list = new JSONArray();
        for(final StatsMessageWithMetadata smwmd : log)
            {
            final JSONArray smja = new JSONArray();
            final StringBuffer sb = new StringBuffer(32);
            Util.appendISODateTime(sb, new Date(smwmd.timestamp));
            smja.add(sb.toString());
            smja.add(smwmd.message);
            smja.add(smwmd.authenticated);
            list.add(smja);
            }
        return(list);
        }

    /**Get most oldest message in log window; null if none. */
    public StatsMessageWithMetadata getOldestMessage()
        { return(lastMessages.peekFirst()); }

    /**Get most recent message in log window; null if none. */
    public StatsMessageWithMetadata getMostRecentMessage()
        { return(lastMessages.peekLast()); }
    }
