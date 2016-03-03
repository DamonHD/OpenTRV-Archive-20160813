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

Author(s) / Copyright (s): Bruno Girin 2015
*/
package uk.org.opentrv.test.statsHandling;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.StringReader;
import java.io.IOException;
import java.io.Reader;
import java.io.InputStreamReader;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

import org.json.simple.parser.ParseException;

import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsHandlerFactory;
import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.cfg.ConfigException;
import uk.org.opentrv.comms.cfg.ListConfigException;

import uk.org.opentrv.comms.statshandlers.builtin.DummyStatsHandler;
import uk.org.opentrv.comms.statshandlers.builtin.SimpleFileLoggingStatsHandler;
import uk.org.opentrv.comms.statshandlers.builtin.twitter.SingleTwitterChannelTemperature;
import uk.org.opentrv.comms.statshandlers.filter.SimpleStaticFilterStatsHandlerWrapper;
import uk.org.opentrv.comms.statshandlers.builtin.openemon.OpenEnergyMonitorPostSimple;
import uk.org.opentrv.comms.statshandlers.mqtt.MqttPublishingHandler;
import uk.org.opentrv.comms.http.RkdapHandler;

public class StatsHandlerFactoryTest {
    /**
     * Test getInstance method
     */
    @Test
    public void testGetInstance() {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        assertNotNull("Returned factory is null", factory);
    }

    /**
     * Test error condition when a new handler list is created from a non-parsable
     * config file.
     *
     * Note on the word parsable: it can be written parseable or parsable but the
     * version without the 'e' is preferred in formal writing as explained here:
     * https://en.wiktionary.org/wiki/parsable
     * Learning the intricacies of English through programming FTW!
     */
    @Test
    public void testNewHandlerListFromNonParsableConfig() {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        StringReader config = new StringReader("This is not valid JSON");
        try {
            List<StatsHandler> handlers = factory.newHandlerList(config);
            fail("Expected ConfigException to be thrown");
        } catch(ConfigException ce) {
            Throwable cause = ce.getCause();
            assertEquals("Unexpected cause type", ParseException.class, cause.getClass());
        }
    }

    /**
     * Test error condition when a new handler list is created from a file that
     * doesn't exist.
     */
    @Test
    public void testNewHandlerListFromNonExistentFile() {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        File config = new File("I_dont_exist.json");
        try {
            List<StatsHandler> handlers = factory.newHandlerList(config);
            fail("Expected ConfigException to be thrown");
        } catch(ConfigException ce) {
            Throwable cause = ce.getCause();
            assertEquals("Unexpected cause type", FileNotFoundException.class, cause.getClass());
        }
    }

    /**
     * Test creating a new handler list from configuration with an empty config.
     */
    @Test
    public void testNewHandlerListEmptyConfig() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        StringReader config = new StringReader("{}");
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 0, handlers.size());
    }

    /**
     * Test creating a new handler list from configuration with an empty handler list.
     */
    @Test
    public void testNewHandlerListEmptyList() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        StringReader config = new StringReader("{\"handlers\":[]}");
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 0, handlers.size());
    }

    /**
     * Test creating a new handler list from configuration with a single handler in it.
     */
    @Test
    public void testNewHandlerListOneHandler() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigOneHandler.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 1, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof MockHandler);
        Map hOptions = ((MockHandler)handler1).getOptions();
        String hText = (String)hOptions.get("text");
        assertNotNull("Missing 'text' option", hText);
        assertEquals("Unexpected value for 'text' option", "Hello World", hText);
        Number hNum = (Number)hOptions.get("number");
        assertNotNull("Missing 'number' option", hNum);
        assertEquals("Unexpected value for 'number' option", 10L, hNum);
    }

    /**
     * Test creating a new handler list from configuration with a single invalid handler in it.
     */
    @Test
    public void testNewHandlerListOneInvalidHandler() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigOneInvalidHandler.json")
        );
        try {
            List<StatsHandler> handlers = factory.newHandlerList(config);
            fail("Expected ListConfigException to be thrown");
        } catch(ListConfigException lce) {
            List<ConfigException> causes = lce.getCauses();
            assertEquals("Unexpected number of causes", 1, causes.size());
        }
    }

    /**
     * Test creating a new hadler list containing a dummy handler.
     */
    @Test
    public void testNewHandlerListDummyHandler() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigDummyHandler.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 1, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof DummyStatsHandler);
    }

    /**
     * Test creating a new handler list from DHD configuration.
     */
    @Test
    public void testNewHandlerListDHD() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigDHD.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 5, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof SimpleFileLoggingStatsHandler);
        StatsHandler handler2 = handlers.get(1);
        assertNotNull("Returned handler is null", handler2);
        assertTrue("Unexpected class for handler", handler2 instanceof SingleTwitterChannelTemperature);
        StatsHandler handler3 = handlers.get(2);
        assertNotNull("Returned handler is null", handler3);
        assertTrue("Unexpected class for handler", handler3 instanceof SingleTwitterChannelTemperature);
        StatsHandler handler4 = handlers.get(3);
        assertNotNull("Returned handler is null", handler4);
        assertTrue("Unexpected class for handler", handler4 instanceof SimpleStaticFilterStatsHandlerWrapper);
        StatsHandler handler5 = handlers.get(4);
        assertNotNull("Returned handler is null", handler5);
        assertTrue("Unexpected class for handler", handler5 instanceof OpenEnergyMonitorPostSimple);
    }

    /**
     * Test creating a new handler list from Emoncms inline.
     */
    @Test
    public void testNewHandlerListEmoncmsInline() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigEmoncmsInline.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 1, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof OpenEnergyMonitorPostSimple);
    }

    /**
     * Test creating a new handler list from Emoncms nickname.
     */
    @Test
    public void testNewHandlerListEmoncmsNickname() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        try {
            Reader config = new InputStreamReader(
                StatsHandlerFactoryTest.class.getResourceAsStream("ConfigEmoncmsNickname.json")
            );
            List<StatsHandler> handlers = factory.newHandlerList(config);
            assertNotNull("Handler list is null",  handlers);
            assertEquals("Unexpected length of list", 1, handlers.size());
            StatsHandler handler1 = handlers.get(0);
            assertNotNull("Returned handler is null", handler1);
            assertTrue("Unexpected class for handler", handler1 instanceof OpenEnergyMonitorPostSimple);
        } catch(ListConfigException ce) {
            List<ConfigException> causes = ce.getCauses();
            assertEquals("Unexpected number of causes", 1, causes.size());
            ConfigException topCause = causes.get(0);
            Throwable rootCause = topCause.getCause().getCause();
            assertEquals("Unexpected root cause type", IOException.class, rootCause.getClass());
            assertEquals(
                "Unexpected root cause message",
                "auth tokens not found @",
                rootCause.getMessage().substring(0, 23)
            );
        }
    }

    /**
     * Test creating a new handler list from DHD configuration.
     */
    @Test
    public void testNewHandlerListBG() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigBG.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 2, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof SimpleFileLoggingStatsHandler);
        StatsHandler handler2 = handlers.get(1);
        assertNotNull("Returned handler is null", handler2);
        assertTrue("Unexpected class for handler", handler2 instanceof RkdapHandler);
    }

    /**
     * Test creating a new handler list from DHD configuration.
     */
    @Test
    public void testNewHandlerListMQTT() throws ConfigException {
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        Reader config = new InputStreamReader(
            StatsHandlerFactoryTest.class.getResourceAsStream("ConfigMQTT.json")
        );
        List<StatsHandler> handlers = factory.newHandlerList(config);
        assertNotNull("Handler list is null",  handlers);
        assertEquals("Unexpected length of list", 2, handlers.size());
        StatsHandler handler1 = handlers.get(0);
        assertNotNull("Returned handler is null", handler1);
        assertTrue("Unexpected class for handler", handler1 instanceof MqttPublishingHandler);
        MqttPublishingHandler handler1mqtt = (MqttPublishingHandler)handler1;
        assertEquals("Unexpected broker URL 1", "tcp://localhost:1883", handler1mqtt.getBrokerURL());
        assertEquals("Unexpected QOS 1", 0, handler1mqtt.getQOS());
        StatsHandler handler2 = handlers.get(1);
        assertNotNull("Returned handler is null", handler2);
        assertTrue("Unexpected class for handler", handler2 instanceof MqttPublishingHandler);
        MqttPublishingHandler handler2mqtt = (MqttPublishingHandler)handler2;
        assertEquals("Unexpected broker URL 2", "tcp://localhost:9000", handler2mqtt.getBrokerURL());
        assertEquals("Unexpected QOS 2", 1, handler2mqtt.getQOS());
    }

    /**
     * Test creating a new handler from an option map.
     */
    @Test
    public void testNewHandler() throws ConfigException {
        Map config = new HashMap();
        config.put(
            "type",
            "uk.org.opentrv.test.statsHandling.StatsHandlerFactoryTest$MockHandler"
        );
        Map options = new HashMap();
        options.put("text", "Hello World");
        options.put("number", 10);
        config.put("options", options);
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        StatsHandler handler = factory.newHandler(config);
        assertNotNull("Returned handler is null", handler);
        assertTrue("Unexpected class for handler", handler instanceof MockHandler);
        Map hOptions = ((MockHandler)handler).getOptions();
        String hText = (String)hOptions.get("text");
        assertNotNull("Missing 'text' option", hText);
        assertEquals("Unexpected value for 'text' option", "Hello World", hText);
        Number hNum = (Number)hOptions.get("number");
        assertNotNull("Missing 'number' option", hNum);
        assertEquals("Unexpected value for 'number' option", 10, hNum);
    }

    /**
     * Test error condition when handler class is incorrect.
     */
    @Test
    public void testNewHandlerInvalidClass() {
        Map config = new HashMap();
        config.put(
            "type",
            "uk.org.opentrv.test.statsHandling.StatsHandlerFactoryTest.MockHandler"
        );
        Map options = new HashMap();
        options.put("text", "Hello World");
        options.put("number", 10);
        config.put("options", options);
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        try {
            StatsHandler handler = factory.newHandler(config);
            fail("Expected ConfigException to be thrown");
        } catch(ConfigException ce) {
            Throwable cause = ce.getCause();
            assertEquals("Unexpected cause type", ClassNotFoundException.class, cause.getClass());
        }
    }

    /**
     * Test error condition when handler class is private.
     */
    @Test
    public void testNewHandlerPrivateClass() {
        Map config = new HashMap();
        config.put(
            "type",
            "uk.org.opentrv.test.statsHandling.StatsHandlerFactoryTest$PrivateMockHandler"
        );
        Map options = new HashMap();
        options.put("text", "Hello World");
        options.put("number", 10);
        config.put("options", options);
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        try {
            StatsHandler handler = factory.newHandler(config);
            fail("Expected ConfigException to be thrown");
        } catch(ConfigException ce) {
            Throwable cause = ce.getCause();
            assertEquals("Unexpected cause type", NoSuchMethodException.class, cause.getClass());
        }
    }

    /**
     * Test error condition when handler class is private.
     */
    @Test
    public void testNewHandlerNoType() {
        Map config = new HashMap();
        Map options = new HashMap();
        options.put("text", "Hello World");
        options.put("number", 10);
        config.put("options", options);
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        try {
            StatsHandler handler = factory.newHandler(config);
            fail("Expected ConfigException to be thrown");
        } catch(ConfigException ce) {
            assertEquals("Unexpected message", "No handler type found", ce.getMessage());
        }
    }

    /**
     * Test creating a new handler from an option map.
     */
    @Test
    public void testNewHandlerNoOptions() throws ConfigException {
        Map config = new HashMap();
        config.put(
            "type",
            "uk.org.opentrv.test.statsHandling.StatsHandlerFactoryTest$MockHandler"
        );
        StatsHandlerFactory factory = StatsHandlerFactory.getInstance();
        StatsHandler handler = factory.newHandler(config);
        assertNotNull("Returned handler is null", handler);
        assertTrue("Unexpected class for handler", handler instanceof MockHandler);
        Map hOptions = ((MockHandler)handler).getOptions();
        assertEquals("Unexpected size of 'options' map", 0, hOptions.size());
    }

    /**
     * Simple mock handler.
     */
    public static class MockHandler implements StatsHandler {
        private final Map options;

        public MockHandler(Map options) {
            this.options = options;
        }

        public Map getOptions() {
            return options;
        }

        public void processStatsMessage(StatsMessageWithMetadata swmd) throws IOException {
            // do nothing
        }
    }

    /**
     * Private mock handler
     */
    private static class PrivateMockHandler extends MockHandler {
        private PrivateMockHandler(Map options) {
            super(options);
        }
    }
}