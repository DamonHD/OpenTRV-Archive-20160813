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
                           Bruno Girin 2014
*/

package uk.org.opentrv.comms.statshandlers;

import java.io.IOException;

/**Stats-handling interface at the concentrator for any message inbound from a leaf.
 * Also handles 'local' messages (starting with '=') from the local OpenTRV RX listener, if any.
 * <p>
 * By default implementations are synchronous,
 * ie the process...() methods block the caller until done.
 */
public interface StatsHandler
     {
    /**Process a (non-empty) remote/leqf stats message as ASCII7 printable text, starting with (for example) '@' (decoded binary) or '{' (JSON).
     * All text characters are in the range [32,126], eg not containing control codes or line breaks.
     * <p>
     * The implementing routine may silently reject lines that it does not understand,
     * or log an error, or throw an exception, though the last is likely to be relatively expensive.
     * <p>
     * Acceptable formats at indicated by leading character:
     * <ul>
     * <li>'{': compact printable ASCII7 JSON with (nominally mixed case alphanumeric, typically lower-case hex) leaf ID field,
     *     eg <code>{"@":"b39a","T|C16":550,"B|mV":3230}</code></li>
     * <li>'@': compact 'binary' as ASCII7 printable ';' separated fields with (upper-case hex) leaf ID as leading '@' field,
     *     eg <code>@2D1A;T18CC;L47;O1</code></li>
     * <li>'=': stats as ASCII7 printable ';' separated fields from local OpenTRV RX node itself,
     *     eg <code>=F0%@20C3;</code> as a bare minimum.</li>
     * </ul>
     * Local stats lines start with a bare minimum in the style:
<pre>
=F0%@20C3;
</pre>
     * with the first letter after the '=' indicating the mode (Frost/Warm/Bake),
     * then the percent open the controlled valve should be,
     * then the temperature in C with a trailing post-point hex digit (ie 1/16ths of a C),
     * then a ';'.
     * <p>
     * There may then follow zero or more sections separated by ';'
     * each starting with a unique letter identifying the section type.
     * and optionally a trailing compact printable ASCII7 JSON object section starting with '{' and ending with '}'.
     *
     * @param swmd stats message wrapped with timestamp and authentication status; never null
     * @param boolean  true if message from leaf has been authenticated
     * @throws IOException  thrown in case unable to record or transmit onward as required.
     */
    void processStatsMessage(StatsMessageWithMetadata swmd) throws IOException;
}
