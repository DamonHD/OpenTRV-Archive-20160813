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
package uk.org.opentrv.comms.statshandlers;

import java.util.Date;
import java.util.Map;

import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import uk.org.opentrv.comms.statshandlers.support.Util;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

/**Immutable (thread-safe) store of stats message as received.
 * Can also extract message in other formats, eg as a Map, where appropriate.
 */
public final class StatsMessageWithMetadata
    {
    /**Full stats message text printable ASCII7 in range [32,126]; not null, not empty. */
    public final String message;
    /**Timestamp of message arrival at concentrator. */
    public final long timestamp;
    /**True if message was authenticated on arrival at concentrator. */
    public final boolean authenticated;

    /**Construct new stats message with its metadata.
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
     * @param message  stats text, consists only of printable ASCII7 in range [32,126]; not null, not empty
     * @param timestamp  timestamp of message arrival at concentrator
     * @param authenticated  true if message was authenticated on arrival at concentrator
     */
    public StatsMessageWithMetadata(final String message, final long timestamp, final boolean authenticated)
        {
        if(null == message) { throw new IllegalArgumentException(); }
        if(message.isEmpty()) { throw new IllegalArgumentException(); }
        this.message = message;
        this.timestamp = timestamp;
        this.authenticated = authenticated;
        }

    /**Get stats type as a char. */
    public char getStatsTypeAsChar() { return(message.charAt(0)); }

    /**Get normalised leaf ID as a String, may be cached; null if not extractable. */
    public String getLeafIDAsString()
        {
        // TODO: consider cacheing
        final String id = Util.extractNormalisedID(message);
        return(id);
        }

    /**Get/parse stats as a Map, may be cached; null if not possible.
     * Values are generally String or Number,
     * but may be more complex such as arrays or nested maps.
     * <p>
     * May be cached.
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> parseStatsAsMap()
        {
        final char statsType = getStatsTypeAsChar();
        switch(statsType)
            {
            case '@': // "Binary" form...
                { return(new ParsedRemoteBinaryStatsRecord(message).getMapByString()); }
            case '{': // JSON form...
                {
                final JSONParser parser = new JSONParser();
                try { return((Map)parser.parse(message)); }
                catch(final ParseException e) { return(null); }
                }
            }
        return(null); // Cannot parse as Map.
        }

    /**Extract Integer value from stats map; null if not possible.
     * Will return exact retrieved item for Integer value,
     * wrapped .intValue() for Number value,
     * or attempts to parse as decimal integer for String value,
     * else null.
     */
    public static Integer getStatMapItemAsInteger(final String key, final Map<String, Object> statsMap)
        {
        if(null == statsMap) { throw new IllegalArgumentException(); }
        if(null == key) { throw new IllegalArgumentException(); }
        final Object o = statsMap.get(key);
        if(null == o) { return(null); }
        if(Integer.class == o.getClass()) { return((Integer) o); }
        if(o instanceof Number) { return(Integer.valueOf(((Number) o).intValue())); }
        if(String.class == o.getClass())
            {
            try { return(Integer.valueOf((String) o, 10)); }
            catch(final NumberFormatException e) { return(null); }
            }
        return(null); // Cannot extract Integer.
        }

    @Override
    public int hashCode()
        {
        int result = authenticated ? 1 : 14;
        result ^= message.hashCode();
        result ^= (int) timestamp;
        return(result);
        }

    @Override
    public boolean equals(final Object obj)
        {
        if(this == obj) { return(true); }
        if(obj == null) { return(false); }
        if(getClass() != obj.getClass()) { return(false); }
        final StatsMessageWithMetadata other = (StatsMessageWithMetadata) obj;
        if(authenticated != other.authenticated) { return(false); }
        if(timestamp != other.timestamp) { return(false); }
        if(!message.equals(other.message)) { return(false); }
        return(true);
        }

    /**Return as compact array of JSON ISO timestamp (to 1s grain), literal stats message text, authenticated; never null nor empty.
     * Output may look like <code>["1970-01-01T01:00:00Z",true,"orginalStatsMessage"]</code>
     * @return
     */
    public String asJSONArrayString()
        {
        final StringBuffer sb = new StringBuffer(32);
        sb.append('[');
            sb.append('"');
            Util.appendISODateTime(sb, new Date(timestamp));
            sb.append('"');
        sb.append(',');
            sb.append('"');
            sb.append(message.replace("\"", "\\\"")); // Escape any " in the stats string.
            sb.append('"');
        sb.append(',');
            sb.append(authenticated ? "true":"false");
        sb.append(']');
        return(sb.toString());
        }

    /**Return human readable-ish form. */
    @Override public String toString() { return(asJSONArrayString()); }
    }
