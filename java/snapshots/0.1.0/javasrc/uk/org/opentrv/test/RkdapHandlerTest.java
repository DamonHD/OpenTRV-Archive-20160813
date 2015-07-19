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

Author(s) / Copyright (s): Bruno Girin 2014, 2015
*/

package uk.org.opentrv.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.MalformedURLException;

import org.junit.Test;

import uk.org.opentrv.comms.http.RkdapHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;

import com.sun.net.httpserver.Headers;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class RkdapHandlerTest {

    /**
     * Test the basic constructor.
     * @throws MalformedURLException
     */
    @Test public void testRkdapHandler() throws MalformedURLException {
        final RkdapHandler handler = new RkdapHandler(
                "https://ED_25@dev.energydeck.com/amr/upload/randomkey");
        assertEquals(
                "Unexpected URL",
                "https://dev.energydeck.com/amr/upload/randomkey",
                handler.getURL().toString());
        assertEquals(
                "Unexpected DAD ID",
                "ED_25",
                handler.getDadID());
    }

    /**
     * Test the basic constructor with a custom port. Custom port was forgotten in the
     * original code so this tests for that condition.
     * @throws MalformedURLException
     */
    @Test public void testRkdapHandlerCustomPort() throws MalformedURLException {
        final RkdapHandler handler = new RkdapHandler(
                "https://ED_25@localhost:8888/amr/upload/randomkey");
        assertEquals(
                "Unexpected URL",
                "https://localhost:8888/amr/upload/randomkey",
                handler.getURL().toString());
        assertEquals(
                "Unexpected DAD ID",
                "ED_25",
                handler.getDadID());
    }

    /**
     * Test the basic constructor exception condition.
     */
    @Test public void testRkdapHandlerException() {
        try {
            final RkdapHandler handler = new RkdapHandler("malformed URL");
            fail("Expected MalformedURLException to be thrown, handler created with URL "+handler.getURL());
        } catch(final MalformedURLException muex) {
            // That's what we expect
        }
    }

    /**
     * Test remote stats processing using an internal simple HTTP server.
     * @throws IOException
     * @throws InterruptedException
     */
    @Test public void testProcessRemoteStats() throws IOException, InterruptedException {
        // Start HTTP server
        final HttpServer server = HttpServer.create(new InetSocketAddress(8888), 0);
        final SimpleHandler handler = new SimpleHandler();
        server.createContext("/test", handler);
        server.setExecutor(null); // creates a default executor
        server.start();
        // Send request
        final RkdapHandler rhandler = new RkdapHandler("http://dadid@localhost:8888/test");
        rhandler.processStatsMessage(new StatsMessageWithMetadata("@A45;T21CC;L35;O1", 1, false));
        // Stop HTTP server
        server.stop(0);
        // Check payload
        final String expectedPayloadTemplate =
                "{"+
                    "\"data\":[" +
                        "{" +
                            "\"id\":\"A45_T\"," +
                            "\"period\":\"0000-00-00T00:00:00\"," +
                            "\"value\":21.75" +
                        "}," +
                        "{" +
                            "\"id\":\"A45_L\"," +
                            "\"period\":\"0000-00-00T00:00:00\"," +
                            "\"value\":35" +
                        "}," +
                        "{" +
                            "\"id\":\"A45_O\"," +
                            "\"period\":\"0000-00-00T00:00:00\"," +
                            "\"value\":1" +
                        "}" +
                    "]," +
                    "\"method\":\"dad_data\"," +
                    "\"ver\":\"1.1\"," +
                    "\"dad_id\":\"ED_25\"" +
                "}";
        final String expectedPayloadHeader = expectedPayloadTemplate.substring(0, 20);
        final String actualPayload = handler.getLastReceivedRequest();
        assertEquals("Unexpected payload length", actualPayload.length(), expectedPayloadTemplate.length());
        assertEquals("Unexpected payload header",
                expectedPayloadHeader,
                actualPayload.substring(0, expectedPayloadHeader.length()));
        // Check headers
        final String[][] expectedHeaders = new String[][]{
                { "Content-Type", "application/json" }
        };
        final Headers actualHeaders = handler.getLastReceivedHeaders();
        for(final String[] expectedHeader : expectedHeaders) {
            final String headerKey = expectedHeader[0];
            final String headerValue = expectedHeader[1];
            assertTrue("Header "+headerKey+" missing", actualHeaders.containsKey(headerKey));
            assertEquals("Unexpected value for header "+headerKey, actualHeaders.getFirst(headerKey), headerValue);
        }
    }

    /**
     * A simple handler that remembers the last received request and headers
     * so that the results can be used in a test case. Note that this class
     * is not thread safe and cannot support multiple concurrent connections.
     * Use it purely for the purpose of tests that require a lightweight
     * HTTP server.
     */
    public static class SimpleHandler  implements HttpHandler {

        private String lastReceivedRequest;

        private Headers lastReceivedHeaders;

        public SimpleHandler() {
            // nothing to do
        }

        public String getLastReceivedRequest() {
            return lastReceivedRequest;
        }

        public Headers getLastReceivedHeaders() {
            return lastReceivedHeaders;
        }

        @Override
        public void handle(final HttpExchange t) throws IOException {
            // Handle request
            final StringBuffer buf = new StringBuffer();
            lastReceivedHeaders = t.getRequestHeaders();
            final InputStream is = t.getRequestBody();
            for (int c; (c = is.read()) >= 0; buf.append((char)c)) {
                ;
                }
            lastReceivedRequest = buf.toString();
            // Send response
            final byte[] response = "OK".getBytes();
            t.sendResponseHeaders(200, response.length);
            final OutputStream os = t.getResponseBody();
            os.write(response);
            os.close();
        }
    }
}
