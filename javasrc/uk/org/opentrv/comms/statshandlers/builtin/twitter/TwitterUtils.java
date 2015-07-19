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

Author(s) / Copyright (s): Damon Hart-Davis 2008--2015
*/
package uk.org.opentrv.comms.statshandlers.builtin.twitter;

import java.io.File;
import java.io.IOException;

import uk.org.opentrv.comms.statshandlers.builtin.BasicCredentialsStore;
import winterwell.jtwitter.OAuthSignpostClient;
import winterwell.jtwitter.Twitter;


/**Twitter Utilities.
 * Handles some common interactions with Twitter.
 */
public final class TwitterUtils
    {
    /**Prevent creation of an instance. */
    private TwitterUtils() { }

    /**Credentials sub-directory/sub-class for Twitter. */
    public static final String CREDENTIALS_SUBDIR_TWITTER = "Twitter";

    /**Get Twitter handle for updates; null if nothing suitable set up.
     * This may test that it actually has authenticated (read/write) access before returning,
     * so obtaining one of these may require network access and significant time.
     */
    public static Twitter getTwitterHandle(final String tUsername)
        throws IOException
        {
        // We need at least a Twitter user ID to do anything; return null if we don't have one.
        if(null == tUsername) { return(null); }

        // Looking for credentials in a file Twitter/<tUsername>.tat within the credentials directory, eg
        //     ~/.V0p2Credentials/Twitter/OpenTRV_S819c.tat
        // for Twitter user OpenTRV_S819c.
        final File credentialsStoreDir = new File(BasicCredentialsStore.PRIVATE_CREDENTIALS_DIR, CREDENTIALS_SUBDIR_TWITTER);
        final File tokensFilename = new File(credentialsStoreDir, tUsername + ".tat");
        final String[] authtokens = BasicCredentialsStore.getAuthTokensFromFile(tokensFilename, false);

        if(null == authtokens) { throw new IOException("auth tokens not found @ " + tokensFilename); }
        if(authtokens.length < 2) { throw new IOException("too few auth tokens @ " + tokensFilename); }

        // Build new client...
        final OAuthSignpostClient client = new OAuthSignpostClient(OAuthSignpostClient.JTWITTER_OAUTH_KEY, OAuthSignpostClient.JTWITTER_OAUTH_SECRET, authtokens[0], authtokens[1]);

        return(new Twitter(tUsername, client));
        }

//    /**If true then resend tweet only when different to current Twitter status.
//     * More robust than only sending when our message changes because Twitter can lose messages,
//     * but will result in any manual tweet followed up by retweet of previous status.
//     */
//    private static final boolean SEND_TWEET_IF_TWITTER_STATUS_DIFFERENT = true;
    }
