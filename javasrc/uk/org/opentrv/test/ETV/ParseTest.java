package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.StringReader;

import org.junit.Test;

import uk.org.opentrv.ETV.parse.NBulkKWHParseByID;

public class ParseTest
    {
    /**Test bulk gas meter parse. */
    @Test public void testNBulkParse() throws IOException
        {
        // Rudimentary test of bad-arg checking.
        try { new NBulkKWHParseByID(-1, null); fail(); } catch(final IllegalArgumentException e) { /* OK */ }
        // Check that just a header, or no matching entries, returns empty rather than an exception.
        assertTrue(new NBulkKWHParseByID(0, new StringReader("house_id,received_timestamp,device_timestamp,energy,temperature")).getKWHByLocalDay().isEmpty());
        }

    }
