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

Author(s) / Copyright (s): Damon Hart-Davis 2014,
                           Bruno Girin 2014
*/

package uk.org.opentrv.comms.util;

import java.io.IOException;
import java.io.OutputStream;
import java.util.List;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;

/**Generic handling of I/O and stats from a single OpenTRV ~V0.2 connection.
 * Use an instance for each communication session.
 * <p>
 * Not thread-safe.
 */
public final class IOHandlingV0p2
    {
    /**Accumulated characters for current input line. */
    private final StringBuilder inputBuf = new StringBuilder();

    /**Process a single new input char from the OpenTRV serial connection.
     * @param handlers list of stats handlers that will do the actual processing
     * @param inputBuf  buffer in which input for a single line is gathered
     * @param os output stream back to the OpenTRV unit, else null if not available
     * @param c  new character from the OpenTRV unit
     * @throws IOException  in case of I/O problems
     */
    public void processInputChar(final List<StatsHandler> handlers,
                                 final OutputStream os,
                                 final char c)
        throws IOException
        {
//        System.out.print(c); // TODO: make optional, as rather CPU-heavy!

        // Deal with CLI prompt immediately...
        if((c == '>') && (0 == inputBuf.length()))
            {
            if(null != os)
                {
                // Exit CLI to save energy (no command queued).
                os.write('E');
                os.write('\n');
                os.flush();
                }
            return;
            }

        else if((c == '\r') || (c == '\n'))
            {
            // End of line; process entire line.

            // Discard empty lines.
            if(0 == inputBuf.length()) { return; }

            try
                {
                switch(inputBuf.charAt(0))
                    {
                    case '=': // Local stats line.
                        {
                        // Treat local stats as always authenticated
                        // as generally passed over local wired connection.
                        processStats(inputBuf.toString(), handlers, true);
                        System.out.println(inputBuf); // Echo to stdout for logging.
                        break;
                        }

                    case '@': case '{': // Remote (binary/JSON) stats line.
                        {
                        processStats(inputBuf.toString(), handlers, false);
//                        System.out.println(inputBuf); // Echo to stdout for logging.
                        break;
                        }

                    case '?': // Error/warning report from OpenTRV.
                        {
                        System.err.println("WARNING: " + inputBuf);
                        break;
                        }

                    case '!': // Error/warning report from OpenTRV.
                        {
                        System.err.println("ERROR: " + inputBuf);
                        break;
                        }

                    default: // Ignore everything else.
                        break;
                    }
                }
            finally
                {
                inputBuf.setLength(0); // Clear buffer regardless of success or failure.
                }

            return;
            }

        else if((c < 32) || (c > 126))
            {
            // Bad character (non-printable ASCII); reject entire line.
            System.err.println("Bad character on line: " + ((int)c) +
                    " after " + inputBuf.length() + " chars: " + inputBuf.toString());
            inputBuf.setLength(0); // Clear buffer.
            }

        // Append char if line not too long already.
        else if(inputBuf.length() < SerialSupportV0p2.MAX_STATS_LINE_CHARS)
            { inputBuf.append(c); }
        }

    /**Process stats messages from connected OpenTRV V0p2 unit with supplied handlers.
     * Delegates the actual processing to each handler in the list in order, synchronously.
     * It is common to wrap blocking handlers in an async wrapper
     * to avoid delaying handling of messages unnecessarily.
     *
     * @param message  the ASCII7 printable stats message to process
     * @param handlers  the list of handlers to delegate processing to; not null not containing nulls
     * @param authenticated  true iff the message is considered authenticated (not spoofed) at the comms layer
     */
    public static void processStats(final String message, final List<StatsHandler> handlers, final boolean authenticated)
        throws IOException
        {
        if((null == handlers) || (handlers.size() == 0)) { return; } // Not recording stats.

        // Capture timestamp immediately after receipt and before calling any handlers.
        // This makes the stamp as accurate as possible
        // and the same across all handlers.
        final long timestamp = System.currentTimeMillis();

        for(final StatsHandler handler : handlers)
            {
            // Don't allow failure of one handler to prevent others being reached for given line.
            try { handler.processStatsMessage(new StatsMessageWithMetadata(message, timestamp, authenticated)); }
            catch(final IOException e) { e.printStackTrace(); }
            }
        }
    }
