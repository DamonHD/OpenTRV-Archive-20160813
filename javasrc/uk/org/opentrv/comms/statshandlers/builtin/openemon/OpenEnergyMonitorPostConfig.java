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

import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsString;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsChar;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsMap;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsStringMap;

import java.io.IOException;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.net.MalformedURLException;

import uk.org.opentrv.comms.cfg.ConfigException;

/**Simple immutable configuration for posting data into OpenEnergyMonitor emonCMS.
 * This will contain a URL base to post to (HTTP or HTTPS),
 * plus API key, plus a set of mappings from input data to output data.
 * <p>
 * The basic principle is to look for inputs in a tuple of
 * (node ID, message type, value name)
 * and possibly some other filter flags such as 'authenticated' and input type,
 * possibly do a transformation such as scaling or force to numeric from string,
 * then push out with a specified node ID and name and value.
 */
public final class OpenEnergyMonitorPostConfig
    {
    /**Credentials sub-directory/sub-class for Twitter. */
    public static final String CREDENTIALS_SUBDIR_EMONCMS = "emoncms";

    /**Configure from Map config.*/
    public OpenEnergyMonitorPostConfig(final Map config) throws MalformedURLException, IOException, ConfigException
    {
        this(
            new OpenEnergyMonitorPostCredentials(config.get("credentials")),
            getAsString(config, "sourceIDIn"),
            getAsChar(config, "statsTypeIn"),
            getAsStringMap(config, "mapping"),
            getAsString(config, "emonNodeOut")
            );
    }

    /**Configure basic destination (server) details, plus mappings from stats key to EMON name.
     * For simplicity this constructor allows only one source OpenTRV node and one destination emon node.
     *
     * @param emonNodeOut  EMON CMS node ID; strictly positive hex or decimal integer
     */
    public OpenEnergyMonitorPostConfig(final OpenEnergyMonitorPostCredentials credentials,
                                       final String sourceIDIn, final char statsTypeIn,
                                       final Map<String, String> fieldNameMapInToOut,
                                       final String emonNodeOut)
        {
//        if(null == serverBaseURL) { throw new IllegalArgumentException(); }
//        if(!"http".equals(serverBaseURL.getProtocol()) && !"https".equals(serverBaseURL.getProtocol())) { throw new IllegalArgumentException(); }
//        if(null == APIKey) { throw new IllegalArgumentException(); }
        if(null == credentials) { throw new IllegalArgumentException(); }
        if(null == sourceIDIn) { throw new IllegalArgumentException(); }
        if(null == fieldNameMapInToOut) { throw new IllegalArgumentException(); }
        if(!isValidEmonNodeID(emonNodeOut)) { throw new IllegalArgumentException(); }
        this.credentials = credentials;
//        this.serverBaseURL = serverBaseURL;
//        this.APIKey = APIKey;
        this.sourceIDIn = sourceIDIn;
        this.statsTypeIn = statsTypeIn;
        // Take immutable defensive copy of map.
        this.fieldNameMapInToOut = Collections.unmodifiableMap(new HashMap<>(fieldNameMapInToOut));
        this.emonNodeOut = emonNodeOut;
        }

    /**EMONCMS access credentials; never null. */
    private final OpenEnergyMonitorPostCredentials credentials;
    /**Get EMONCMS access credentials; never null. */
    public OpenEnergyMonitorPostCredentials getCredentials() { return(credentials); }
//    private final URL serverBaseURL;
//    public URL getServerBaseURL() { return(serverBaseURL); }
//    private final String APIKey;
//    public String getAPIKey() { return(APIKey); } // TODO: consider making this less accessible for security reasons...

    private final String sourceIDIn;
    private final char statsTypeIn;
    private final Map<String, String> fieldNameMapInToOut;

    /**EMON CMS node ID; non-null. non-empty, non-"0", alphanumeric. */
    private final String emonNodeOut;

    /**True iff there are mappings from the given source/node ID for the given stats type. */
    public boolean isInterestingMessage(final char statsType, final String sourceID)
        { return((statsTypeIn == statsType) && sourceIDIn.equals(sourceID)); }

    /**Get emon name mapped from given key from given input node, or null if none. */
    public String keyMapsToName(final char statsType, final String sourceID, final String sourceKey)
        {
        if(!isInterestingMessage(statsType, sourceID)) { return(null); }
        return(fieldNameMapInToOut.get(sourceKey));
        }

    /**Get (strictly positive) integer emon node mapped from given key from given input node, or null if none.
     * May return non-negative value even in some cases where the is no mapping,
     * so not to be used as an indication of a viable mapping in itself.
     */
    public String keyMapsToNode(final char statsType, final String sourceID, final String sourceKey)
        {
        if(!isInterestingMessage(statsType, sourceID)) { return(null); }
        return(emonNodeOut);
        }

    /**Returns true if the supplied putative emon node ID is valid and must not be null nor empty.
     * The putative ID must be ASCII7 alphanumeric, ie from the alphabet [0-9a-zA-Z].
     * The value '0' is reserved.
     */
    public static boolean isValidEmonNodeID(final String emonNodeOut)
        {
        if(null == emonNodeOut) { return(false); }
        if(emonNodeOut.isEmpty()) { return(false); }
        for(int i = emonNodeOut.length(); --i >= 0; )
            {
            final char c = emonNodeOut.charAt(i);
            if((c >= 'a') && (c <= 'z')) { continue; }
            if((c >= 'A') && (c <= 'Z')) { continue; }
            if((c >= '0') && (c <= '9')) { continue; }
            return(false); // Bad char: reject.
            }
        if("0".equals(emonNodeOut)) { return(false); } // Reserved value.
        return(true); // Seems OK.
        }
    }
