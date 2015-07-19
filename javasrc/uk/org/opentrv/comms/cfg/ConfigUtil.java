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

package uk.org.opentrv.comms.cfg;

import java.io.File;
import java.io.Reader;
import java.io.FileReader;
import java.io.IOException;
import java.io.FileNotFoundException;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.Set;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/**
 * Utility methods to read config options.
 */
public class ConfigUtil {
	public static String getAsString(Map config, String key) {
		Object o = config.get(key);
		if (null == o) {
			return null;
		} else {
			return o.toString();
		}
	}

	public static String getAsString(Map config, String key, String def) {
		String s = getAsString(config, key);
		if (null == s) {
			return def;
		} else {
			return s;
		}
	}

	public static char getAsChar(Map config, String key) {
		return getAsChar(config, key, '\0');
	}

	public static char getAsChar(Map config, String key, char def) {
		String s = getAsString(config, key);
		if (null == s || s.length() < 1) {
			return def;
		} else {
			return s.charAt(0);
		}
	}

	public static Number getAsNumber(Map config, String key) throws ConfigException {
		Object o = config.get(key);
		if (null == o) {
			return null;
		} else if (o instanceof Number) {
			return (Number)o;
		} else {
			throw new ConfigException("Expected Number for key "+key+", got "+o.getClass());
		}
	}

	public static Number getAsNumber(Map config, String key, Number def) throws ConfigException {
		Number n = getAsNumber(config, key);
		if (null == n) {
			return def;
		} else {
			return n;
		}
	}

	public static Map getAsMap(Map config, String key) throws ConfigException {
		Object o = config.get(key);
		if (null == o) {
			return null;
		} else if (o instanceof Map) {
			return (Map)o;
		} else {
			throw new ConfigException("Expected Map for key "+key+", got "+o.getClass());
		}
	}

	public static Map getAsMap(Map config, String key, Map def) throws ConfigException {
		Map m = getAsMap(config, key);
		if (null == m) {
			return def;
		} else {
			return m;
		}
	}

	public static Map<String, String> getAsStringMap(Map config, String key) throws ConfigException {
		Object o = config.get(key);
		if (null == o) {
			return null;
		} else if (o instanceof Map) {
			Map<String, String> r = new HashMap<String, String>();
			Set<Map.Entry> entries = ((Map)o).entrySet();
			for (Map.Entry e : entries) {
				Object oKey = e.getKey();
				Object oValue = e.getValue();
				if (null != oKey && null != oValue) {
					r.put(oKey.toString(), oValue.toString());
				}
			}
			return r;
		} else {
			throw new ConfigException("Expected Map for key "+key+", got "+o.getClass());
		}
	}

	public static Map<String, String> getAsStringMap(Map config, String key, Map<String, String> def) throws ConfigException {
		Map<String, String> m = getAsStringMap(config, key);
		if (null == m) {
			return def;
		} else {
			return m;
		}
	}

	public static List getAsList(Map config, String key) throws ConfigException {
		Object o = config.get(key);
		if (null == o) {
			return null;
		} else if (o instanceof List) {
			return (List)o;
		} else {
			throw new ConfigException("Expected List for key "+key+", got "+o.getClass());
		}
	}

	public static List getAsList(Map config, String key, List def) throws ConfigException {
		List l = getAsList(config, key);
		if (null == l) {
			return def;
		} else {
			return l;
		}
	}

	public static Map loadConfigFile(Reader fileContent) throws ConfigException {
        JSONParser parser = new JSONParser();
        try {
            return (Map)parser.parse(fileContent);
        } catch(ParseException pe) {
            throw new ConfigException("Could not parse configuration", pe);
        } catch(IOException ioe) {
            throw new ConfigException("Could not read configuration", ioe);
        }
	}

	public static Map loadConfigFile(File file) throws ConfigException {
        try {
			return loadConfigFile(new FileReader(file));
        } catch(FileNotFoundException fnfe) {
            throw new ConfigException("Config file not found", fnfe);
        }
	}
}