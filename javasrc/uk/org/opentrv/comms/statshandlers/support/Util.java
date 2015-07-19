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
package uk.org.opentrv.comms.statshandlers.support;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.text.FieldPosition;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Map;
import java.util.Random;
import java.util.TimeZone;
import java.util.concurrent.locks.ReentrantReadWriteLock;

import org.json.simple.parser.JSONParser;

public final class Util
    {
    /**8-bit ISO-8859-1 file encoding. */
    public static final String FILE_ENCODING_8859_1 = "ISO-8859-1";

    /**8-bit UTF-8 file encoding. */
    public static final String FILE_ENCODING_UTF_8 = "UTF-8";

    /**7-bit ASCII file encoding, also by definition valid ISO-8859-1 and UTF-8. */
    public static final String FILE_ENCODING_ASCII7 = "ASCII7";

    /**Prefix used on temporary files, eg while doing atomic replacements. */
    public static final String F_tmpPrefix = ".tmp.";


    /**Lock object for touch and rate-limit to serialise operations per process (or class loader).
     * This aims to reduce the chance of a race within the file system.
     * <p>
     * This may also make an in-process cache plausible.
     */
    private static final Object touchLock = new Object();

    /**Touch the specified file, creating if necessary. */
    public static void touch(final File f) throws IOException
        {
        synchronized(touchLock)
            {
            if(!f.exists())
                { new FileOutputStream(f, true).close(); }
            else
                { f.setLastModified(System.currentTimeMillis()); }
            }
        }


    /**Replaces an existing published file with a new one (see 3-arg version).
     * Is verbose when it replaces the file.
     */
    public static boolean replacePublishedFile(final String name, final byte data[])
        throws IOException
        { return(replacePublishedFile(name, data, false)); }

    /**Replaces an existing published file with a new one.
     * This replaces (atomically if possible) the existing file (if any)
     * of the given name, ensuring the correct permissions for
     * a file to be published with a Web server (ie basically
     * global read permissions), provided the following
     * conditions are met:
     * <p>
     * <ul>
     * <li>The filename extension is acceptable (not checked yet).
     * <li>The data array is non-null and not zero-length.
     * <li>The content of the data array is different to the file.
     * <li>All the required permissions are available.
     * </ul>
     * <p>
     * If the file is successfully replaced, true is returned.
     * <p>
     * If the file does not need replacing, false is returned
     * (and the file is not replaced or touched).
     * <p>
     * If an error occurs, eg in the input data or during file
     * operations, an IOException is thrown.
     * <p>
     * This routine enforces locking so that only one such
     * operation may be performed at any one time.  This does
     * not avoid the possibility of externally-generated races.
     * <p>
     * The final file, once replaced, will be globally readable,
     * and writable by us.
     * <p>
     * (If the final component of the file starts with ".",
     * then the file will be accessible only by us.)
     *
     * @param quiet     if true then only error messages will be output
     */
    public static boolean replacePublishedFile(final String name, final byte data[],
                                               final boolean quiet)
        throws IOException
        {
        if((name == null) || (name.length() == 0))
            { throw new IOException("inappropriate file name"); }
        final int length = data.length;
        if((data == null) || (length == 0))
            { throw new IOException("inappropriate file content"); }

        final File extant = new File(name);

        // Lock the critical external bits against read and write updates.
        rPF_rwlock.writeLock().lock();
        try
            {
            final File tempFile = makeTempFileNameInSameDirAsTarget(extant);

            // Get extant file's length.
            final long oldLength = extant.length();
            // Should we overwrite it?
            boolean overwrite = (oldLength < 1); // Missing or zero length.

            // If length has changed, we should overwrite.
            if(length != oldLength) { overwrite = true; }

            // Now, if we haven't already decided to overwrite the file,
            // check the content.
            if(!overwrite)
                {
                try
                    {
                    final InputStream is = new BufferedInputStream(
                        new FileInputStream(extant));
                    try
                        {
                        final int l = length;
                        for(int i = 0; i < l; ++i)
                            {
                            if(data[i] != is.read())
                                { overwrite = true; break; }
                            }
                        }
                    finally
                        { is.close(); }
                    }
                catch(final FileNotFoundException e) { overwrite = true; }
                }

            // OK, we don't want to overwrite, so return.
            if(!overwrite) { return(false); }


            // OVERWRITE OLD FILE WITH NEW...

            try {
                // Write new temp file...
                // (Allow any IOException to terminate the function.)
                FileOutputStream os = new FileOutputStream(tempFile);
                try
                    {
                    os.write(data);
                    // Force to underlying media (eg fsync()).
                    os.flush();
                    os.getFD().sync();
                    }
                finally { os.close(); }
                os = null; // Help GC.
                if(tempFile.length() != length)
                    { new IOException("temp file not written correctly"); }

                // Attempt to atomically (or nearly so) replace extant file with tempfile.
                return(_atomicishFileReplace(extant, tempFile, length, quiet));
                }
            finally // Tidy up...
                {
                tempFile.delete(); // Remove the temp file.
                }
            }
        finally { rPF_rwlock.writeLock().unlock(); }

        // Can't get here...
        }

    /**Attempt to atomically (or nearly so) replace extant file with tempfile.
     * FIXME: Where renameTo() not atomic, rename old file to .bak version to preserve it in case of crash
     */
    private static boolean _atomicishFileReplace(final File extant, final File tempFile,
            final int length, final boolean quiet)
        throws IOException
        {
        final boolean globalRead = !extant.getName().startsWith(".");

        // Ensure that the temp file has the correct read permissions.
        tempFile.setReadable(true, !globalRead);
        tempFile.setWritable(true, true);

        // Warn if target does not have write perms, and try to add them.
        // This should allow us to replace it with the new file.
        final boolean alreadyExists = extant.exists();
        if(alreadyExists && !extant.canWrite())
            {
            System.err.println("FileTools.replacePublishedFile(): "+
                "WARNING: " + extant + " not writable.");
            extant.setWritable(true, true);
            if(!extant.canWrite())
                {
                throw new IOException("can't make target writable");
                }
            }

        // (Atomically) move tempFile to extant file.
        // Note that renameTo() may not be atomic
        // and we may have to remove the target file first.
        if(!tempFile.renameTo(extant))
            {
            // If the target already exists,
            // then be prepared to explicitly delete it.
            if(!alreadyExists || !extant.delete() || !tempFile.renameTo(extant))
                { throw new IOException("renameTo/update of "+extant+" failed"); }
            if(!quiet) { System.err.println("[WARNING: atomic replacement not possible for: " + extant + ": used explicit delete.]"); }
            }

        if((length >= 0) && (extant.length() != length))
            { new IOException("update of "+extant+" failed"); }
        extant.setReadable(true, !globalRead);
        extant.setWritable(true, true);
        if(!quiet) { System.err.println("["+(alreadyExists?"Updated":"Created")+" " + extant + "]"); }
        return(true); // All seems OK.
        }

    /**Create a new temporary filename for the same directory as the extant file; never null.
     * A file in the same directory is usually guaranteed to be in the same filesystem,
     * and thus may often allow an atomic update/replace
     * and in any case ensures that we cannot run out of space
     * (barring other concurrent unrelated activity in the filesystem)
     * when we try to replace the extant file with the temporary one.
     * <p>
     * To avoid internal races this should be generated and used
     * within the scope of our internal 'filesystem update' lock.
     * <p>
     * The generated name starts with the 'temporary' prefix.
     */
    private static File makeTempFileNameInSameDirAsTarget(final File extant)
        {
        // Use a temporary file in the same directory (and thus the same filesystem)
        // to avoid unexpectedly truncating the file when copying/moving it.
        File tempFile;
        for( ; ; )
            {
            tempFile = new File(extant.getParent(),
                F_tmpPrefix +
                Long.toString((rnd.nextLong() >>> 1),
                    Character.MAX_RADIX) /* +
                "." +
                extant.getName() */ ); // Avoid making very long names...
            if(tempFile.exists())
                {
                System.err.println("WARNING: FileTools.replacePublishedFile(): "+
                    "temporary file " + tempFile.getPath() +
                    " exists, looping...");
                continue;
                }
            break;
            }
        return(tempFile);
        }

    /**OK PRNG for generating parts of filenames, etc; not null. */
    private static final Random rnd = new Random();

    /**Private lock for replacePublishedFile().
     * We use a read/write lock to improve available concurrency.
     * <p>
     * TODO: We could extend this to a lock per distinct directory or filesystem.
     */
    private static final ReentrantReadWriteLock rPF_rwlock = new ReentrantReadWriteLock();

    /**Makes a publicly-readable directory path if not already present.
     * Like File.mkdirs(), but attempts to ensure that any directory
     * component created by this routine is publicly readable
     * and searchable, ie at least permissions read and execute
     * for all.  Final permissions will usually be 0755,.
     * <p>
     * Optionally, a new empty index.html file can be created
     * inside any directory that is created as a simple Web security
     * precaution, at least until something is put in its place.
     * <p>
     * If this routine fails it may have succeeded in creating some of the necessary
     * parent directories.
     * <p>
     * This shares a lock with replacePublishedFile().
     * <p>
     * (This routine should maybe be merged with makeHTMLSubDirs(),
     * though the relationship is not trivial.)
     *
     * @return  <code>true</code> if and only if the directory was created,
     *          along with all necessary parent directories; <code>false</code>
     *          otherwise
     */
    public static boolean makePublishingDir(final File path)
        throws IOException
        {
        rPF_rwlock.writeLock().lock();
        try
            {
            if(path.exists()) { return(false); } // Nothing we can do...
            if(path.mkdir())
                {
                path.setWritable(true, true);
                path.setReadable(true, false);
                path.setExecutable(true, false);
                return(true);
                }
            final String parent = path.getParent();
            if(parent == null) { return(false); }
            if(!makePublishingDir(new File(parent))) { return(false); }
            if(!path.mkdir()) { return(false); }
            path.setWritable(true, true);
            path.setReadable(true, false);
            path.setExecutable(true, false);
            return(true);
            }
        finally { rPF_rwlock.writeLock().unlock(); }
        }

    /**Read text file into a String.
     * Reads a line at a time, trimming whitespace off either
     * end and putting in a single new line at the end instead.
     * <p>
     * This treats the file as ISO-8859-1 8-bit data.
     *
     * @exception IOException  in case of trouble
     */
    public static String readTextFile(final File f)
        throws IOException
        {
        final StringBuilder sb = new StringBuilder((int) f.length());
        BufferedReader br = null;
        try {
            br = new BufferedReader(
                    new InputStreamReader(
                        new FileInputStream(f), FILE_ENCODING_8859_1));
            String inputLine;
            while((inputLine = br.readLine()) != null)
                { sb.append(inputLine.trim()); sb.append('\n'); }
            }
        finally
            {
            // Try to close the file (possibly provoking an exception)...
            if(br != null) { br.close(); br = null; }
            }
        return(sb.toString());
        }


    /**Extract and return normalised ID from text status message; null if none.
     * This supports '@' and '{' formats.
     * <p>
     * Case-sensitive IDs (eg in '{' format) are returned as-is,
     * and all-upper-case IDs (eg in '@' format) are converted to lower-case
     * and padded on the left with '0' to an even number of (hex) digits.
     * <p>
     * This attempts to be efficient,
     * and in particular may be able to avoid parsing the entire message.
     */
    public static String extractNormalisedID(final String statsMessage)
        {
        if(null == statsMessage) { return(null); }
        // Fast parse for 'binary' ('@') format.
        if(statsMessage.startsWith("@"))
            {
            final int sc = statsMessage.indexOf(';', 1);
            if(-1 == sc) { return(null); }
            final String putative = statsMessage.substring(1, sc).toLowerCase();
            // Pad odd-length ID on left with "0" to even number of digits (whole number of bytes).
            if(0 != (putative.length() & 1)) { return("0" + putative); }
            return(putative);
            }

        // Fast parse attempt for compact JSON ('{') format.
        if(statsMessage.startsWith("{\"@\":\""))
            {
            final int dq = statsMessage.indexOf('"', 6);
            if(-1 == dq) { return(null); } // Won't be parseable.
            final String putative = statsMessage.substring(1, dq);
            // Only allow fast-parse if no escaping before the closing double-quote.
            final int bs = putative.indexOf('\\');
            if(-1 != bs) { return(putative.toLowerCase()); }
            // Fall through to slow full parse, ie may be parseable...
            }
        // Full parse for compact JSON ('{') format.
        if(statsMessage.startsWith("{"))
            {
            final JSONParser parser = new JSONParser();
            try
                {
                final Map json = (Map)parser.parse(statsMessage);
                return((String) json.get("@"));
                }
            // Failed to parse.
            catch(final Exception e) { return(null); }
            }

        // Format not recognised.
        return(null);
        }


    /**Simple persistent rate limit; returns false if it is too soon to do the specified operation.
     * Throws and exception if the rate-limit persistent storage is not accessible/usable.
     * <p>
     * Note that the rate limit is shared across all processes for this user
     * that can see its home directory; results may be unreliable if the home directory is networked.
     * <p>
     * This persists a flag for the operation in the filesystem,
     * touching it when the operation is performed,
     * and refusing it if the last operation happened too recently.
     * <p>
     * Flag purging should be done with care, not in the normal course of events.
     * The result of a purge call to remove the flag is always false,
     * ie the specified operation should *not* be performed afterwards.
     *
     * @param operation  unique operation name; must be safe to use as part of a filename; non-null, non-empty
     * @param minMinutesSpacing  minimum minutes between operations; strictly positive, else -1 to purge flag
     */
    public static boolean canDoRateLimitedOperation(final String uniqueOperationID, final int minMinutesSpacing) throws IOException
        {
        final boolean purgeFlag = (-1 == minMinutesSpacing);
        if(!purgeFlag && (minMinutesSpacing <= 0)) { throw new IllegalArgumentException(); }
        final String userHomeS = System.getProperty("user.home");
        if((null == userHomeS) || ("".equals(userHomeS))) { throw new IOException("bad user.home property"); }
        final File userHome = new File(userHomeS);
        final File flagsDir = new File(userHome, ".V0p2HubOpsRateLimitFlags");
        if(!flagsDir.exists())
            {
            if(!userHome.exists() && !userHome.isDirectory()) { throw new IOException("bad user.home dir: " + userHome); }
            flagsDir.mkdir();
            if(!flagsDir.exists())  { throw new IOException("unable to create rate-limit flags dir: " + flagsDir); }
            }

        final File flag = new File(flagsDir, uniqueOperationID + ".flag");
        final long minFlagAge = System.currentTimeMillis() - (minMinutesSpacing * 60_000L);
        synchronized(touchLock)
            {
            if(purgeFlag)
                {
                flag.delete();
                return(false); // Do NOT perform the operation.
                }
            // TODO: note that touch timestamps (to VETO an op) are locally cacheable for at least 60s...
            final long ts = flag.lastModified();
            // Return false if too soon since last op.
            if(ts >= minFlagAge) { return(false); }
            touch(flag);
            // Flag updated; caller should perform the operation.
            return(true);
            }
        }


    /**Append ISO-8601 UTC full date and time format with Z (eg 2011-12-03T10:15:30Z) to buffer. */
    public static final void appendISODateTime(final StringBuffer sb, final Date dt)
        {
        synchronized(dateAndTimeISO8601) { dateAndTimeISO8601.format(dt, sb, new FieldPosition(0)); }
        }

    /**ISO-8601 UTC full date and time format with Z (eg 2011-12-03T10:15:30Z); hold lock on this instance while using for thread-safety. */
    private static final SimpleDateFormat dateAndTimeISO8601 = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
    { dateAndTimeISO8601.setTimeZone(TimeZone.getTimeZone("UTC")); }
    }
