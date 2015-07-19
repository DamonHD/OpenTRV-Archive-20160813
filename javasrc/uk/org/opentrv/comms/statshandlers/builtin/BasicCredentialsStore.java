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

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**Basic management of confidential credentials, eg for distribution of data across the Internet.
 * This includes file-based storage of such credentials.
 */
public final class BasicCredentialsStore
    {
    /**Per-user default directory for credentials storage; never null.
     * On UNIX-like systems is a directory within the home directory of the process' user,
     * with 'safe' permissions such as 700 (read/write/execute for user only).
     * <p>
     * Generally within this will be subdirectories containing the credentials
     * for different classes of downstream distribution, such as "Twitter".
     * <p>
     * This may also be used for holding secret keys shared with leaf nodes.
     */
    public static final File PRIVATE_CREDENTIALS_DIR = new File(System.getProperty("user.home"), ".V0p2Credentials");

    /**Extract a (non-empty) set of non-empty auth tokens from the specified file, or null if none or if the filename is bad.
     * This does not throw an exception if it cannot find or open the specified file
     * (or the file name is null or empty)
     * or it the file does not contain any token;
     * for all these cases null is returned.
     * <p>
     * Each token must be on a separate line.
     * <p>
     * There must be at least two token else this will return null.
     *
     * @param tokensFilename  name of file containing auth token(s) or null/empty if none
     * @param quiet  if true then keep quiet about file errors
     * @return non-null, non-empty tokens
     */
    public static String[] getAuthTokensFromFile(final File tokensFilename, final boolean quiet)
        {
        // Null file name results in quiet return of null.
        if(null == tokensFilename) { return(null); }

        if(!tokensFilename.canRead())
            {
            if(!quiet)
                {
                System.err.println("Cannot open pass file for reading: " + tokensFilename);
                try { System.err.println("  Canonical path: " + tokensFilename.getCanonicalPath()); } catch(final IOException e) { }
                }
            return(null);
            }

        try
            {
            final List<String> result = new ArrayList<String>();
            final BufferedReader r =  new BufferedReader(new FileReader(tokensFilename));
            try
                {
                String line;
                while(null != (line = r.readLine()))
                    {
                    final String trimmed = line.trim();
                    if(trimmed.isEmpty()) { return(null); } // Give up with *any* blank token.
                    result.add(trimmed);
                    }
//                if(result.size() < 2) { return(null); } // Give up if not (at least) two tokens.
                if(result.isEmpty()) { return(null); } // Give up no tokens.
                // Return non-null non-empty token(s).
                return(result.toArray(new String[result.size()]));
                }
            finally { r.close(); /* Release resources. */ }
            }
        // In case of error whinge but continue.
        catch(final Exception e)
            {
            if(!quiet) { e.printStackTrace(); }
            return(null);
            }
        }
    }
