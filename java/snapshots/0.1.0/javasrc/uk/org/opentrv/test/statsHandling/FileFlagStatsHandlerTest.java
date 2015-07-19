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
package uk.org.opentrv.test.statsHandling;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.FileFlagStatsHandler;

public class FileFlagStatsHandlerTest
    {
    /**Private temp directory to do work in created for each test and cleared down after; never null during tests. */
    private Path tempDir;

    @Before
    public void before() throws Exception
        {
        tempDir = Files.createTempDirectory(null);
        }

    @After
    public void after() throws Exception
        {
        // Delete the directory tree.
        Files.walkFileTree(tempDir, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult visitFile(final Path file, final BasicFileAttributes attrs) throws IOException {
                Files.delete(file);
                return(FileVisitResult.CONTINUE);
            }
            @Override
            public FileVisitResult postVisitDirectory(final Path dir, final IOException exc) throws IOException {
                Files.delete(dir);
                return(FileVisitResult.CONTINUE);
            }
        });
        // Check that it has been cleared.
        if(tempDir.toFile().exists()) { throw new AssertionError("cleanup failed: " + tempDir); }
        tempDir = null;
        }

    @Test
    public void testFileFlagStatsHandlerBasics() throws IOException
        {
        assertEquals("No flags should have been created yet", 0, tempDir.toFile().list().length);
        final FileFlagStatsHandler ffsh0 = new FileFlagStatsHandler(tempDir.toString());
        assertEquals("No flags should have been created yet", 0, tempDir.toFile().list().length);
        ffsh0.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"b39a\",\"T|C16\":308,\"B|mV\":3247}", System.currentTimeMillis(), false));
        assertEquals("1 (non-auth) flag should have been created", 1, tempDir.toFile().list().length);
        assertTrue((new File(tempDir.toFile(), "b39a.flg")).exists());
        ffsh0.processStatsMessage(new StatsMessageWithMetadata("@D49;T17C6;L61;O1", System.currentTimeMillis(), true));
        assertEquals("3 flags should have been created", 3, tempDir.toFile().list().length);
        assertTrue((new File(tempDir.toFile(), "b39a.flg")).exists());
        assertTrue((new File(tempDir.toFile(), "0d49.flg")).exists());
        assertTrue((new File(tempDir.toFile(), "0d49.afl")).exists());
        }

    }
