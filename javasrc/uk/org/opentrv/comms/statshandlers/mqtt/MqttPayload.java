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

Author(s) / Copyright (s): Bruno Girin 2016 */

package uk.org.opentrv.comms.statshandlers.mqtt;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;

import org.json.simple.JSONArray;
import org.json.simple.JSONAware;
import org.json.simple.JSONObject;

import uk.org.opentrv.comms.util.CommonSensorLabels;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

/**
 * Lightweight object that represents a MQTT payload.
 * @author Bruno Girin
 *
 */
public class MqttPayload implements JSONAware {

    /*
     * Constants used to construct the JSON payload
     */
    public static final String DATA_TIMESTAMP_KEY = "ts";
    public static final String DATA_BODY_KEY = "body";

    public static final DateFormat PERIOD_DATE_FORMAT = new SimpleDateFormat(
            "yyyy-MM-dd'T'HH:mm:ss'Z'");
    { PERIOD_DATE_FORMAT.setTimeZone(TimeZone.getTimeZone("UTC")); }

    private final String leafTopic;
    private final long timestamp;
    private final JSONObject data;

    /**
     * Create a MQTT payload given a parsed binary record.
     */
    public MqttPayload(final ParsedRemoteBinaryStatsRecord record) {
        this.timestamp = record.constructionTime;
        this.data = new JSONObject();
        this.leafTopic = record.ID;
        for(final Map.Entry<Character, String> entry :
            record.sectionsByKey.entrySet()) {
            final String entryKey = entry.getKey().toString();
            // Ignore the @ entry as it's part of the key anyway
            if(!"@".equals(entryKey)) {
                Number value = null;
                if(CommonSensorLabels.TEMPERATURE.getLabel() == entry.getKey().charValue()) {
                    value = ParsedRemoteBinaryStatsRecord.parseTemperatureFromDDCH(entry.getValue());
                } else {
                    try {
                        value = Integer.parseInt(entry.getValue());
                    } catch(final NumberFormatException nfe1) {
                        try {
                            value = Double.parseDouble(entry.getValue());
                        } catch(final NumberFormatException nfe2) {
                            continue;
                        }
                    }
                }
                data.put(entryKey, value);
            }
        }
    }

    /**
     * Create a MQTT payload given a JSON record.
     */
    public MqttPayload(final long constructionTime, final JSONObject record) {
        this.timestamp = constructionTime;
        this.data = new JSONObject();
        final Object deviceIDObj = record.get("@");
        if(deviceIDObj != null) {
            leafTopic = deviceIDObj.toString().toUpperCase();
            for(final Object entryKeyObj : record.keySet()) {
                final String entryKey = entryKeyObj.toString();
                if(!"@".equals(entryKey)) {
                    final int pipePos = entryKey.indexOf('|');
                    final String sensorID;
                    final String sensorUnit;
                    final String processedKey;
                    if(pipePos > 0) {
                        sensorID = entryKey.substring(0, pipePos);
                        sensorUnit = entryKey.substring(pipePos + 1);
                    } else {
                        sensorID = entryKey;
                        sensorUnit = "";
                    }
                    final String entryValue = record.get(entryKey).toString();
                    Number value = null;
                    if("C16".equals(sensorUnit)) {
                        try {
                            value = Integer.parseInt(entryValue)/16.0;
                        } catch(final NumberFormatException nfe) {
                            continue;
                        }
                        processedKey = sensorID + "|C";
                    } else {
                        try {
                            value = Integer.parseInt(entryValue);
                        } catch(final NumberFormatException nfe1) {
                            try {
                                value = Double.parseDouble(entryValue);
                            } catch(final NumberFormatException nfe2) {
                                continue;
                            }
                        }
                        processedKey = entryKey;
                    }
                    data.put(processedKey, value);
                }
            }
        } else {
            leafTopic = "";
        }
    }

    @Override
    public String toJSONString() {
        return toJSONObject().toString();
    }

    public JSONObject toJSONObject() {
        final JSONObject payload = new JSONObject();
        payload.put(DATA_TIMESTAMP_KEY, PERIOD_DATE_FORMAT.format(new Date(this.timestamp)));
        payload.put(DATA_BODY_KEY, this.data);
        return payload;
    }

    public String getLeafTopic() {
        return this.leafTopic;
    }
}
