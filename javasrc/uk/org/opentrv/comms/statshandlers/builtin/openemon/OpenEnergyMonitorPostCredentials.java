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

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Map;

import uk.org.opentrv.comms.statshandlers.builtin.BasicCredentialsStore;

/**Simple immutable credentials for posting data into OpenEnergyMonitor emonCMS.
 * This will contain a URL base to post to (HTTP or HTTPS),
 * plus API key, plus a set of mappings from input data to output data.
 */
public final class OpenEnergyMonitorPostCredentials
    {
    /**Configure from map.*/
    public OpenEnergyMonitorPostCredentials(final Object config) throws IOException
        {
        this(getEmoncmsAuthTokens(config));
        }

    /**Configure basic destination (server) details. */
    public OpenEnergyMonitorPostCredentials(final URL serverBaseURL, final String APIKey)
        {
        if(null == serverBaseURL) { throw new IllegalArgumentException(); }
        if(!"http".equals(serverBaseURL.getProtocol()) && !"https".equals(serverBaseURL.getProtocol())) { throw new IllegalArgumentException(); }
        if(null == APIKey) { throw new IllegalArgumentException(); }
        this.serverBaseURL = serverBaseURL;
        this.APIKey = APIKey;
        }

    /**Configure basic destination details using auth tokens. */
    private OpenEnergyMonitorPostCredentials(final String[] authtokens) throws MalformedURLException
        {
        this(new URL(authtokens[0]), authtokens[1]);
        }

    /**Base URL, http or https schemes, for V8.4-style emoncms access; never null. */
    private final URL serverBaseURL;
    /**Get base URL, http or https schemes, for V8.4-style emoncms access; never null. */
    public URL getServerBaseURL() { return(serverBaseURL); }

    /**API key for V8.4-style emoncms access; never null. */
    private final String APIKey;
    /**Get API key for V8.4-style emoncms access; never null. */
    public String getAPIKey() { return(APIKey); } // TODO: consider making this less accessible for security reasons...

    /**Can extract credentials from Map (as part of system JSON config) or by String name from local store. */
    private static String[] getEmoncmsAuthTokens(final Object config)
        throws IOException
        {
        if (null == config) { throw new IllegalArgumentException(); }
        if (config instanceof Map)
            {
            final Map mConfig = (Map)config;
            return new String[]
                {
                getAsString(mConfig, "serverBaseURL"),
                getAsString(mConfig, "APIKey")
                };
            }

        // Get credentials from local store.
        return(getEmoncmsAuthTokens(config.toString()));
        }

    /**Get emoncms base URL and API key as a String pair; null if nothing suitable set up.
     * This may test that it actually has authenticated (read/write) access before returning,
     * so obtaining one of these may require network access and significant time.
     *
     * @param emonServerNickname  alphanumeric nickname of emoncms server; non-null and non-empty
     */
    private static String[] getEmoncmsAuthTokens(final String emonServerNickname)
        throws IOException
        {
        // We need at least a Twitter user ID to do anything; return null if we don't have one.
        if(null == emonServerNickname) { return(null); }

        // Looking for credentials in a file emoncms/<emonServerNickname>.tat within the credentials directory, eg
        //     ~/.V0p2Credentials/emoncms/emonserver1.tat
        // for 'emonserver1'.
        final File credentialsStoreDir = new File(BasicCredentialsStore.PRIVATE_CREDENTIALS_DIR, OpenEnergyMonitorPostConfig.CREDENTIALS_SUBDIR_EMONCMS);
        final File tokensFilename = new File(credentialsStoreDir, emonServerNickname + ".tat");
        final String[] authtokens = BasicCredentialsStore.getAuthTokensFromFile(tokensFilename, false);

        if(null == authtokens) { throw new IOException("auth tokens not found @ " + tokensFilename); }
        if(authtokens.length < 2) { throw new IOException("too few auth tokens @ " + tokensFilename); }

        return authtokens;
        }

    /**Get emoncms base URL and API key as a String pair; null if nothing suitable set up.
     * This may test that it actually has authenticated (read/write) access before returning,
     * so obtaining one of these may require network access and significant time.
     *
     * @param emonServerNickname  alphanumeric nickname of emoncms server; non-null and non-empty
     */
    public static OpenEnergyMonitorPostCredentials getEmoncmsCrentials(final String emonServerNickname)
        throws IOException
        {
        final String[] authtokens = getEmoncmsAuthTokens(emonServerNickname);

        return(new OpenEnergyMonitorPostCredentials(authtokens));
        }
    }
