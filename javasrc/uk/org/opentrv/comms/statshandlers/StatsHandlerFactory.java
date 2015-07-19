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

package uk.org.opentrv.comms.statshandlers;

import static uk.org.opentrv.comms.cfg.ConfigUtil.loadConfigFile;

import java.lang.reflect.Constructor;
import java.io.File;
import java.io.Reader;
import java.io.FileReader;
import java.io.IOException;
import java.io.FileNotFoundException;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

//import org.json.simple.JSONObject;
//import org.json.simple.parser.JSONParser;
//import org.json.simple.parser.ParseException;

import uk.org.opentrv.comms.cfg.ConfigException;
import uk.org.opentrv.comms.cfg.ListConfigException;

/**
 * Singleton factory object that is able to create a list of handlers from
 * a Map of JSONObject.
 */
public class StatsHandlerFactory {
    private static final StatsHandlerFactory instance = new StatsHandlerFactory();

    private StatsHandlerFactory() {
        // do nothing
    }

    /**
     * Retrieve the singleton instance of this class.
     */
    public static StatsHandlerFactory getInstance() {
        return instance;
    }

    /**Create a new handler list from a configuration object.
     * This can be a Map or a JSONObject read from file.
     */
    public List<StatsHandler> newHandlerList(final Map config) throws ConfigException {
        List<StatsHandler> result = new ArrayList<StatsHandler>();
        List<Map> handlerConfigs = (List<Map>)config.get("handlers");
        if(handlerConfigs != null) {
            ListConfigException errors = null;
            for (Map handlerConfig : handlerConfigs) {
                try {
                    result.add(newHandler(handlerConfig));
                } catch(ConfigException ce) {
                    if (errors == null) {
                        errors = new ListConfigException(
                            "Some handlers could not be created"
                        );
                    }
                    errors.addCause(ce);
                }
            }
            if (errors != null) {
                throw errors;
            }
        }
        return result;
    }

    /**
     * Create a new handler list from a config available through a reader.
     */
    public List<StatsHandler> newHandlerList(final Reader config) throws ConfigException {
        return newHandlerList(loadConfigFile(config));
    }

    /**
     * Create a new handler list from a configuration file.
     */
    public List<StatsHandler> newHandlerList(final File config) throws ConfigException {
        return newHandlerList(loadConfigFile(config));
    }

    /**
     * Create a new handler from a configuration object.
     */
    public StatsHandler newHandler(final Map config) throws ConfigException {
        Object hTypeO = config.get("type");
        if (hTypeO == null) {
            throw new ConfigException("No handler type found");
        }
        String hType = hTypeO.toString();
        Map hOptions = null;
        Object hOptionsO = config.get("options");
        if (hOptionsO == null) {
            hOptions = new HashMap();
        } else if(hOptionsO instanceof Map) {
            hOptions = (Map)hOptionsO;
        } else {
            throw new ConfigException("Invalid options structure");
        }
        try {
            Class hClass = Class.forName(hType);
            Constructor hConstruct = hClass.getConstructor(Map.class);
            return (StatsHandler)hConstruct.newInstance(hOptions);
        } catch(ClassNotFoundException cnfe) {
            throw new ConfigException("Invalid handler type", cnfe);
        } catch(NoSuchMethodException nsme) {
            throw new ConfigException(
                "Handler class has no public constructor that takes options as parameter",
                nsme
            );
        } catch(Exception e) {
            throw new ConfigException("Could not create handler", e);
        }
    }
}