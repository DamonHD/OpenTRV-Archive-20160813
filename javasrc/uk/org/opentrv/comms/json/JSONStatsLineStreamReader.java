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

package uk.org.opentrv.comms.json;

import java.io.BufferedReader;
import java.io.FilterReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;


/**Filter a line-oriented JSON stream for a particular stat and ID.
 * The input from a Reader is one JSON array per line with the UTC/ISO timestamp, concentrator ID, and raw lightweight sensor JSON,
 * of the form:
<pre>
[ "2014-12-19T15:39:50Z", "", {"@":"0a45","+":5,"L":163,"B|mV":3315,"v|%":0,"tT|C":7} ]
[ "2014-12-19T15:40:18Z", "", {"@":"819c","T|C16":156,"L":206,"B|cV":256} ]
[ "2014-12-19T15:41:20Z", "", {"@":"2d1a","+":3,"v|%":0,"tT|C":7,"O":1,"vac|h":6} ]
[ "2014-12-19T15:41:50Z", "", {"@":"0a45","+":6,"L":157,"O":1,"vac|h":18,"T|C16":284} ]
[ "2014-12-19T15:42:00Z", "", {"@":"f1c6","+":3,"B|mV":2533,"v|%":0,"tT|C":14,"O":1} ]
[ "2014-12-19T15:42:06Z", "", {"@":"414a","+":4,"L":53,"O":1,"vac|h":7,"T|C16":277} ]
[ "2014-12-19T15:42:10Z", "", {"@":"0d49","+":3,"B|mV":2601,"v|%":0,"tT|C":7,"O":1} ]
[ "2014-12-19T15:42:28Z", "", {"@":"3015","+":5,"L":236,"B|mV":2550,"v|%":0} ]
[ "2014-12-19T15:43:06Z", "", {"@":"414a","+":5,"L":51,"B|mV":3315,"v|%":0,"tT|C":7} ]
[ "2014-12-19T15:43:10Z", "", {"@":"0d49","+":4,"L":228,"vac|h":7,"T|C16":288} ]
</pre>
 */
public final class JSONStatsLineStreamReader extends FilterReader
    {
    /**Field to filter on; never null. */
    private final String field;

    /**Leaf/node ID of stats/records to accept; null if to accept records from all IDs. */
    private final String id;

    /**Next line of output, starting at specified offset (offsetNLO), or null if none remaining. */
    private String nextLineOut;
    /**Offset in nextLineOut of next char to output; never >= nextLineOut.length(); */
    private int offsetNLO;

    /**Construct a new filter with the specified input stream and filter parameters.
     * @param in  input stream, array-per-line JSON as described in the class comment; never null
     * @param field  name of field to extract; never null
     * @param id  leaf ID (as in "@" field) to select values from; null means all leaf values
     * @param concentratorID  concentrator ID to select values from; null means all concentrators
     */
    public JSONStatsLineStreamReader(final Reader in, final String field, final String id, final String concentratorID)
        {
        super((in instanceof BufferedReader) ? in : new BufferedReader(in));
        if(null == field) { throw new IllegalArgumentException(); }
        if(null != concentratorID) { throw new IllegalArgumentException("concentratorID match not implemented"); }
        this.field = field;
        this.id = id;
        }

    /**Construct a new filter with the specified input stream and filter parameters.
     * @param in  input stream, array-per-line JSON as described in the class comment; never null
     * @param field  name of field to extract; never null
     * @param id  leaf ID (as in "@" field) to select values from; null means all leaf values
     */
    public JSONStatsLineStreamReader(final Reader in, final String field, final String id)
        { this(in, field, id, null); }

    /**Construct a new filter with the specified input stream and filter parameter.
     * @param in  input stream, array-per-line JSON as described in the class comment; never null
     * @param field  name of field to extract; never null
     */
    public JSONStatsLineStreamReader(final Reader in, final String field)
        { this(in, field, null); }

    /**Implement single-char read in terms of multi-char read. */
    @Override
    public int read() throws IOException
        {
        // Optimisation, where there is pending text in the output buffer.
        if(null != nextLineOut)
            {
            final int result = nextLineOut.charAt(offsetNLO++);
            if(nextLineOut.length() == offsetNLO) { nextLineOut = null; } // Cleared pending output...
            return(result);
            }
        // Revert to default read() impl.
        final char buf[] = new char[1];
        if(-1 == read(buf, 0, 1)) { return(-1); }
        return(buf[0]);
        }

    /**Normal multi-char read.
     * Lazily parses more from the input only as needed to produce another line of output.
     */
    @Override
    public int read(final char[] cbuf, final int off, final int len) throws IOException
        {
        if(len <= 0) { throw new IllegalArgumentException(); }

        for( ; ; )
            {
            // Deal with any pending output first.
            if(null != nextLineOut)
                {
                final int charsBuffered = nextLineOut.length() - offsetNLO;
                assert(charsBuffered > 0);
                final int toCopy = Math.min(charsBuffered, len);
                for(int i = 0; i < toCopy; ++i) { cbuf[off+i] = nextLineOut.charAt(offsetNLO++); }
                if(charsBuffered == toCopy) { nextLineOut = null; } // Cleared pending output...
                return(toCopy);
                }

            // Read a line/record from the underlying input to parse
            // until something matches the filtering and allows output to be generated,
            // stopping if EOF is encountered.
            final String lineIn = ((BufferedReader)in).readLine();
            if(null == lineIn) { return(-1); } // EOF.

            // Parse the input and prepare the new string output.
            final Object o = JSONValue.parse(lineIn); // FIXME: use retained parser for efficiency.
            if(!(o instanceof JSONArray)) { throw new IOException("input line is not a JSON array: " + lineIn); }
            final JSONArray array = (JSONArray)o;
            if(3 != array.size()) { throw new IOException("input line JSON array has wrong number of elements: " + lineIn); }
            if(!(array.get(0) instanceof String)) { throw new IOException("input line timestamp ([0]) is not a string: " + lineIn); }
            final String timeStamp = (String) array.get(0);
            if(!(array.get(2) instanceof JSONObject)) { throw new IOException("input line leaf JSON ([2]) is not an object/map: " + lineIn); }
            final JSONObject leafObject = (JSONObject)array.get(2);

            // If the filter is not matched (or items are missing/bogus),
            // continue to the next input line/record, if any.
            final Object ido = leafObject.get("@");
            if(null == ido) { continue; } // No ID so cannot match...
            if(!(ido instanceof String))  { throw new IOException("ID (@ field) must be a string: " + lineIn); }
            final String id = (String) ido;
            if((null != this.id) && !this.id.equals(id)) { continue; } // Failed ID match.
            final Object fo = leafObject.get(field);
            if(null == fo) { continue; } // No match...
            // Generate '\n'-terminated output.
            final StringBuilder sb = new StringBuilder(32);
            sb.append(timeStamp).append(' ').
               append(id).append(' ').
               append(fo).append('\n');
            // Checks that the correct number of fields have been generated, eg no spurious spaces.
            final String out = sb.toString();
            if(3 != out.split(" ").length) { throw new IOException("cannot construct safe output from: " + lineIn); }

            offsetNLO = 0;
            nextLineOut = out;
            }
        }

    @Override
    public void close() throws IOException
        {
        nextLineOut = null; // Abandon any pending output.
        super.close();
        }

    // mark() and reset() are not supported.
    @Override public boolean markSupported() { return(false); }
    @Override public void mark(final int m) { }
    @Override public void reset() { }


    /**Allow this filter to be run directly from the command line.
     * Filters from System.in to System.out.
     * <p>
     * Arguments are fieldName [leafID [concentratorID]].
     */
    public static void main(final String args[])
        {
        if(args.length < 1)
            {
            System.err.println("fieldName [leafID [concentratorID]]");
            System.exit(1);
            return;
            }

        try
            {
            try(final BufferedReader br = new BufferedReader(new JSONStatsLineStreamReader(new InputStreamReader(System.in),
                    args[0],
                    (args.length > 1) ? args[1] : null,
                    (args.length > 2) ? args[1] : null)))
                {
                for( ; ; )
                    {
                    final String line = br.readLine();
                    if(null == line) { break; }
                    System.out.println(line);
                    }
                }
            }
        catch(final IOException e)
            {
            e.printStackTrace();
            System.exit(2);
            return;
            }
        }
    }
