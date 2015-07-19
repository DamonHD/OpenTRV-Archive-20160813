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
package uk.org.opentrv.comms.statshandlers.builtin.openemon;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.net.MalformedURLException;

import org.json.simple.JSONObject;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.cfg.ConfigException;

/**Post to OpenEMON CMS (http://openenergymonitor.org/) servers over HTTP.
 * Simple (not necessarily hugely efficient) driver to post values into EMONCMS.
 * <p>
 * This translates incoming values and posts them one at a time to EMONCMS V8.4+ like this:
 * <code>emoncms/api/post?apikey=YOURAPIKEY&json={power:200.2}</code>
 * <code>http://A.B.C.D/emoncms/api/post?apikey=blahblah&node=1&json={Temp16:386}</code>
 * <p>
 * eg see: http://openenergymonitor.org/emon/node/6315
 * and: https://www.ibm.com/developerworks/community/blogs/B-Fool/entry/sending_data_from_node_red_to_emoncms?lang=en
 * <p>
 * Probably obsolete but see by contrast: http://openenergymonitor.org/emon/node/127
 * <p>
 * Not thread-safe.
 */
public class OpenEnergyMonitorPostSimple implements StatsHandler, AutoCloseable
    {
    /**Immutable configuration for this channel; never null. */
    protected final OpenEnergyMonitorPostConfig config;

    /**Create and configure an instance using a map config.*/
    public OpenEnergyMonitorPostSimple(final Map config) throws MalformedURLException, IOException, ConfigException
        {
        this(new OpenEnergyMonitorPostConfig(config));
        }

    /**Create and configure an instance. */
    public OpenEnergyMonitorPostSimple(final OpenEnergyMonitorPostConfig config)
        {
        if(null == config) { throw new IllegalArgumentException(); }
        this.config = config;
        }

    /**Stateless conversion of input message to zero or more logical emoncms updates based on config; never null.
     * Outputs are all numeric.
     * <p>
     * Outputs may be sent one at a time to emoncms.
     * <p>
     * Primarily exposed to enable testing.
     *
     * @return map from emonNode to set of emon name/values pairs; never null
     *
     * @throws NumberFormatException  if unable to convert mapped value to Number
     */
    public static Map<String, Map<String,Number>> convertMessages(final OpenEnergyMonitorPostConfig config, final StatsMessageWithMetadata swmd)
        {
        final String sourceID = swmd.getLeafIDAsString();
        if(null == sourceID) { return(Collections.emptyMap()); }
        final char statsType = swmd.getStatsTypeAsChar();
        if(!config.isInterestingMessage(statsType, sourceID)) { return(Collections.emptyMap()); }
        final Map<String, Map<String,Number>> result = new HashMap<>();
        final Map<String, Object> statsAsMap = swmd.parseStatsAsMap();
        for(final String sourceKey : statsAsMap.keySet())
            {
            final String emonName = config.keyMapsToName(statsType, sourceID, sourceKey);
            if(null == emonName) { continue; }
            final String emonNode = String.valueOf(config.keyMapsToNode(statsType, sourceID, sourceKey));
            Map<String, Number> forNode = result.get(emonNode);
            if(null == forNode)
                {
                // Create node for emon.
                forNode = new HashMap<>();
                result.put(emonNode, forNode);
                }
            final Object v = statsAsMap.get(sourceKey);
            if(v instanceof Number) { forNode.put(emonName, (Number)v); }
            else if(v instanceof String) { forNode.put(emonName, Double.parseDouble((String) v)); }
            else { throw new NumberFormatException("do not know how to convert type to Number for "+ sourceKey); }
            }

        // Optimisation: allow GC of redundant empty 'result' quicker.
        if(result.isEmpty()) { return(Collections.emptyMap()); }

        return(result);
        }

    /**Create the GET URL to send the specified data points to an EMON CMS V8.4+; non-null.
     * The base URL has emoncms/api/post appended plus a query string with values appended for
     * apikey, node, and json, the last being a JSON object containing the (numeric) data values
     * for which the keys should be pure ASCII7 alphanumeric and the keys decimal numbers.
     * @param emonNodeOut pure ASCII7 alphanumeric string (eg hex or decimal positive integer); never null
     * @throws UnsupportedEncodingException
     * @throws MalformedURLException
     */
    public static URL createGETURLToSendDataToEmonCMSV8p4(final OpenEnergyMonitorPostConfig config, final String emonNodeOut, final Map<String,Number> data)
        throws MalformedURLException
        {
        if(!OpenEnergyMonitorPostConfig.isValidEmonNodeID(emonNodeOut)) { throw new MalformedURLException(); }
        final StringBuilder sb = new StringBuilder("emoncms/api/post?");
        try
            {
            sb.append("apikey=").append(URLEncoder.encode(config.getCredentials().getAPIKey(), "UTF-8")).
                append('&');
            sb.append("node=").append(emonNodeOut). // Emon CMS node name should not need encoding.
                append('&');
            sb.append("json=").append(URLEncoder.encode(JSONObject.toJSONString(data), "UTF-8"));
            }
        catch(final UnsupportedEncodingException e) { throw new Error("internal error", e); }
        final URL result = new URL(config.getCredentials().getServerBaseURL(), sb.toString());
        return(result);
        }

    /**Sends the specified data points to the EMON CMS V8.4+; returns true in case of success. */
    public static boolean sendDataToEmonCMSV8p4(final OpenEnergyMonitorPostConfig config, final String emonNodeOut, final Map<String,Number> data)
        {
        try {
            final URL u = createGETURLToSendDataToEmonCMSV8p4(config, emonNodeOut, data);
            final HttpURLConnection huc = (HttpURLConnection) u.openConnection();
            huc.setUseCaches(false); // False a new connection.
            huc.connect();
            final int code = huc.getResponseCode();
            huc.disconnect();
            if(200 == code) { return(true); }
            }
        catch(final IOException e) { return(false); }
        return(false);
        }

    /**If true always send values one at a time to emoncms, else send in (possibly-partial) groups. */
    private static final boolean SEND_VALUES_TO_EMON_INDIVIDUALLY = false;

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd)
            throws IOException
        {
        final Map<String, Map<String,Number>> toSend = convertMessages(config, swmd);
        if(toSend.isEmpty()) { return; }

        for(final String emonNode : toSend.keySet())
            {
            final Map<String,Number> values = toSend.get(emonNode);
            if(SEND_VALUES_TO_EMON_INDIVIDUALLY)
                {
                // Now send each value separately to avoid confusing emon CMS.
                for(final Map.Entry<String, Number> me : values.entrySet())
                    {
                    if(!sendDataToEmonCMSV8p4(config, emonNode, Collections.singletonMap(me.getKey(), me.getValue())))
                        { throw new IOException("unable to send for emon CMS node " + emonNode); }
                    }
                }
            else
                {
                // Send in groups.
                if(!sendDataToEmonCMSV8p4(config, emonNode, values))
                    { throw new IOException("unable to send for emon CMS node " + emonNode); }
                }
            }
        }


    /**Release resources. */
    @Override
    public void close() throws Exception
        {
        // Nothing to do for now; could dispose of cached state.
        }
    }
