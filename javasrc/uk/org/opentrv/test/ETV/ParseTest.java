package uk.org.opentrv.test.ETV;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.org.opentrv.ETV.parse.NBulkKWHParseByID;

public class ParseTest
    {
    /**Test bulk gas meter parse. */
    @Test public void testNBulkParse()
        {
        // Rudimentary test of bad-arg checking.
        try { new NBulkKWHParseByID(-1, null); fail(); } catch(final IllegalArgumentException e) { /* OK */ }
        }

    }
