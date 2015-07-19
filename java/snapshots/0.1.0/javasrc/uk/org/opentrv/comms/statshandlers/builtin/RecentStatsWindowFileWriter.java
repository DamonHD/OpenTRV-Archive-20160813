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
package uk.org.opentrv.comms.statshandlers.builtin;

import java.io.File;
import java.io.IOException;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.support.RecentStatsWindow;
import uk.org.opentrv.comms.statshandlers.support.Util;

/**Writes JSON snapshot of recent stats to specified file as events arrive.
 * Not thread-safe; intended to be used at a single end-point sink.
 */
public final class RecentStatsWindowFileWriter implements StatsHandler
    {
    /**Target file to be updated with the collated data. */
    final File targetFile;

    /**Where data is accumulated and collated; not null. */
    private final RecentStatsWindow rsw;

    /**Specify (non-null) target file; must be writable/createable as a plain file. */
    public RecentStatsWindowFileWriter(final File targetFile) { this(targetFile, RecentStatsWindow.DEFAULT_WINDOW_MS); }

    /**Create instance specifying a non-default window, and target file.
     * @param targetFile  target file name, must be writable/createable as a plain file; never null
     * @param window_ms  maximum window size in milliseconds; strictly positive
     */
    public RecentStatsWindowFileWriter(final File targetFile, final long window_ms)
        {
        if(null == targetFile) { throw new IllegalArgumentException(); }
        this.targetFile = targetFile;
        rsw = new RecentStatsWindow(window_ms);
        }

    /**Accept a new stats message.
     * @param swmd  the stats message to add; never null
     * @throws IOException  out-of-order message (bad timestamp) or other issue
     */
    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd)
        throws IOException
        {
        rsw.processStatsMessage(swmd);

        // Update file with new snapshot...
        // Output is list whose first element is the current-values map keyed by ID, and second is the log (as a list)
        final JSONArray outerArray = new JSONArray();
        final JSONObject valueMap = new JSONObject(); // FIXME: not yet populated.
        outerArray.add(valueMap);
        outerArray.add(rsw.getRecentStatsMessagesInOrderAsJSONArray());
        Util.replacePublishedFile(targetFile.getPath(), outerArray.toString().getBytes(Util.FILE_ENCODING_ASCII7), true);
        }

    }
