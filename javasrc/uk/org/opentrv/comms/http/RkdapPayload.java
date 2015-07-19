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

package uk.org.opentrv.comms.http;

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
 * Lightweight object that represents a RKDAP payload.
 * @author Bruno Girin
 *
 */
public class RkdapPayload implements JSONAware {

	/*
	 * Constants used to construct the JSON payload
	 */
	public static final String METHOD_KEY = "method";
	public static final String METHOD_VALUE = "dad_data";
	public static final String VERSION_KEY = "ver";
	public static final String VERSION_VALUE = "1.1";
	public static final String DAD_ID_KEY = "dad_id";
	public static final String DATA_KEY = "data";
	public static final String DATA_ID_KEY = "id";
	public static final String DATA_PERIOD_KEY = "period";
	public static final String DATA_VALUE_KEY = "value";

	public static final DateFormat PERIOD_DATE_FORMAT = new SimpleDateFormat(
			"yyyy-MM-dd'T'HH:mm:ss");
    { PERIOD_DATE_FORMAT.setTimeZone(TimeZone.getTimeZone("UTC")); }

	private final String dadId;
	private final long timestamp;
	private final List<DataItem> dataItems;

    /**
     * Create a RKDAP payload given a parsed binary record.
     */
	public RkdapPayload(final String dadId, final ParsedRemoteBinaryStatsRecord record) {
		this.dadId = dadId;
		this.timestamp = record.constructionTime;
		this.dataItems = new ArrayList<DataItem>();
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
			    dataItems.add(new DataItem(
					    record.ID,
					    entryKey,
					    this.timestamp,
					    value
			    ));
		    }
		}
	}

    /**
     * Create a RKDAP payload given a JSON record.
     */
	public RkdapPayload(final String dadId, final long constructionTime, final JSONObject record) {
		this.dadId = dadId;
		this.timestamp = constructionTime;
		this.dataItems = new ArrayList<DataItem>();
		final Object deviceIDObj = record.get("@");
		if(deviceIDObj != null) {
		    final String deviceID = deviceIDObj.toString().toUpperCase();
    		for(final Object entryKeyObj : record.keySet()) {
    		    final String entryKey = entryKeyObj.toString();
    		    if(!"@".equals(entryKey)) {
    		        final int pipePos = entryKey.indexOf('|');
    		        final String sensorID;
    		        final String sensorUnit;
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
			        }
    		        dataItems.add(new DataItem(
    		            deviceID,
    		            sensorID,
    		            this.timestamp,
    		            value
		            ));
	            }
    		}
		}
	}

    @Override
    public String toJSONString() {
        return toJSONObject().toString();
    }

    public JSONObject toJSONObject() {
        final JSONObject payload = new JSONObject();
        payload.put(METHOD_KEY, METHOD_VALUE);
        payload.put(VERSION_KEY, VERSION_VALUE);
        payload.put(DAD_ID_KEY, this.dadId);
        final JSONArray dataArray = new JSONArray();
        for(final DataItem item: this.dataItems) {
            dataArray.add(item.toJSONObject());
        }
        payload.put(DATA_KEY, dataArray);
        return payload;
    }

	public static class DataItem {
		private final String deviceID;
		private final String sensorID;
		private final long timestamp;
		private final Number value;

		public DataItem(final String deviceID, final String sensorID, final long timestamp, final Number value) {
			this.deviceID = deviceID;
			this.sensorID = sensorID;
			this.timestamp = timestamp;
			this.value = value;
		}

		public JSONObject toJSONObject() {
		    final JSONObject item = new JSONObject();
		    item.put(DATA_ID_KEY, this.deviceID+"_"+this.sensorID);
		    item.put(DATA_PERIOD_KEY, PERIOD_DATE_FORMAT.format(new Date(this.timestamp)));
		    item.put(DATA_VALUE_KEY, this.value);
		    return item;
	    }
	}
}
