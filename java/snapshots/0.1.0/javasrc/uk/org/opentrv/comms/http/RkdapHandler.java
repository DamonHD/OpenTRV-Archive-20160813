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
                           Bruno Girin 2014, 2015 */

package uk.org.opentrv.comms.http;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.util.CommonSensorLabels;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

/**
 * Stats handler that sends data over HTTP POST using the RKDAP format
 * as supported by ResourceKraft and EnergyDeck.
 * <p>
 * The RKDAP format is a simple JSON format. It requires a DAD ID
 * (Data Acquisition Device Identifier) that is assigned by the system
 * the URL points to.
 */
public final class RkdapHandler implements StatsHandler {

    public static final String REQUEST_METHOD = "POST";
    public static final String CHARSET = "UTF-8";
    public static final String CONTENT_TYPE_KEY = "Content-Type";
    public static final String CONTENT_TYPE_VALUE = "application/json";
    public static final String CONTENT_LENGTH_KEY = "Content-Length";

    private final URL url;
    private final String dadId;

    /**
     * Create a new RkdapHandler from a full URL. This URL is expected to include
     * the DAD ID in its user info part so should be of the form:
     * <pre>
     * http[s]://dad_id@host/path
     * </pre>
     * @param fullUrl the full URL including DAD ID
     * @throws MalformedURLException
     */
    public RkdapHandler(final String fullUrl) throws MalformedURLException {
        final URL tmpUrl = new URL(fullUrl);
        this.url = new URL(
                tmpUrl.getProtocol(),
                tmpUrl.getHost(),
                tmpUrl.getPort(),
                tmpUrl.getFile());
        this.dadId = tmpUrl.getUserInfo();
    }

    /**
     * Create a new RdkapHandler from a URL and DAD ID.
     *
     * @param url the URL without the DAD ID information
     * @param dadID the DAD ID to use by the handler
     * @throws MalformedURLException
     */
    public RkdapHandler(final String url, final String dadID) throws MalformedURLException {
        this.url = new URL(url);
        this.dadId = dadID;
    }

    public URL getURL() {
        return url;
    }

    public String getDadID() {
        return dadId;
    }

    /**
     * Remote stats handler that sends data to the specified URL using the
     * RKDAP format. The payload is JSON and contains one entry for each
     * metric on the stats line. The ID for each metric is a combination of
     * the line's ID and the single character key. All metrics are given the
     * same timestamp obtained when creating the record.
     * <p>
     * This is intended to process the printable-ASCII form of remote binary stats lines starting with '@', eg:
     * <pre>
@D49;T19C7
@2D1A;T20C7
@A45;P;T21CC
@3015;T25C8;L62;O1
     * </pre>
     * and remote JSON stats lines starting with '{', eg:
<pre>
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":87,"L":231,"B|cV":256}
{"@":"cdfb","T|C16":296,"H|%":88,"L":229,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":227,"B|cV":256}
{"@":"cdfb","T|C16":297,"H|%":89,"L":229,"B|cV":256}
</pre>
     * <p>
     * Example payload:
     * <pre>
     * {
     *     "method":"dad_data",
     *     "ver":"1.1",
     *     "dad_id":"ED_25",
     *     "data":[
     *         {"id":"A45_T","period":"2014-08-23T10:25:12","value":21.75"},
     *         {"id":"A45_L","period":"2014-08-23T10:25:12","value":35"},
     *         {"id":"A45_O","period":"2014-08-23T10:25:12","value":1"}
     *     ]
     * }
     * </pre>
     */
    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException {
        final char firstChar = swmd.message.charAt(0);
        final RkdapPayload payloadObj;
        if('{' == firstChar) {
            // Process potential JSON; reject if bad.
            final long nowms = System.currentTimeMillis();
            final JSONParser parser = new JSONParser();
            try {
                final Object obj = parser.parse(swmd.message);
                final JSONObject jsonObj = (JSONObject)obj;
                payloadObj = new RkdapPayload(dadId, nowms, jsonObj);
            } catch(final ParseException pe) {
                return;
            }
        } else if(CommonSensorLabels.ID.getLabel() == firstChar) {
            // Process potential binary record.
            final ParsedRemoteBinaryStatsRecord parsed = new ParsedRemoteBinaryStatsRecord(swmd.message);
            payloadObj = new RkdapPayload(dadId, parsed);
        } else {
            // Ignore all other lines.
            return;
        }
        System.out.println("Sending: "+payloadObj.toJSONString());
        final byte[] payload = payloadObj.toJSONString().getBytes(CHARSET);

        final HttpURLConnection conn = (HttpURLConnection)this.url.openConnection();
        conn.setRequestMethod(REQUEST_METHOD);
        conn.setRequestProperty(CONTENT_TYPE_KEY, CONTENT_TYPE_VALUE);
        conn.setRequestProperty(CONTENT_LENGTH_KEY, String.valueOf(payload.length));
        conn.setDoOutput(true);
        conn.setDoInput(true);
        conn.getOutputStream().write(payload);

        final Reader in = new BufferedReader(new InputStreamReader(conn.getInputStream(), CHARSET));
        for (int c; (c = in.read()) >= 0; System.out.print((char)c)) {
            }
    }

}
