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

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.junit.Test;

import uk.org.opentrv.comms.http.RkdapPayload;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

public class RkdapPayloadTest {

	/**
	 * Test the JSON output generated from a binary payload.
	 */
	@Test public void testToJSONStringFromBinary() {
    	final ParsedRemoteBinaryStatsRecord pr1 = new ParsedRemoteBinaryStatsRecord("@A45;T21CC;L35;O1");
    	final Date ctime = new Date(pr1.constructionTime);
    	final DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
    	dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    	final String date = dateFormat.format(ctime);
    	final DateFormat timeFormat = new SimpleDateFormat("HH:mm:ss");
    	timeFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    	final String time = timeFormat.format(ctime);
    	final RkdapPayload payload = new RkdapPayload("ED_25", pr1);
    	final String json = payload.toJSONString();
    	assertEquals("Unexpected payload",
    			"{"+
    				"\"ver\":\"1.1\"," +
    				"\"method\":\"dad_data\"," +
    				"\"data\":[" +
    					"{" +
    						"\"period\":\""+date+"T"+time+"\"," +
    						"\"id\":\"A45_T\"," +
    						"\"value\":21.75" +
						"}," +
    					"{" +
							"\"period\":\""+date+"T"+time+"\"," +
							"\"id\":\"A45_L\"," +
							"\"value\":35" +
						"}," +
    					"{" +
							"\"period\":\""+date+"T"+time+"\"," +
							"\"id\":\"A45_O\"," +
							"\"value\":1" +
						"}" +
    				"]," +
    				"\"dad_id\":\"ED_25\"" +
    			"}",
    			json);
	}


	/**
	 * Test the JSON output generated from a JSON payload.
	 */
	@Test public void testToJSONStringFromJSON() throws Exception {
    	final String jsonRecord = "{\"@\":\"cdfb\",\"T|C16\":298,\"H|%\":87,\"L\":231,\"B|cV\":256}";
        final JSONParser parser = new JSONParser();
        final Object obj = parser.parse(jsonRecord);
        final JSONObject jsonObj = (JSONObject)obj;
    	final long nowms = System.currentTimeMillis();
    	final Date ctime = new Date(nowms);
    	final DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
    	dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    	final String date = dateFormat.format(ctime);
    	final DateFormat timeFormat = new SimpleDateFormat("HH:mm:ss");
    	timeFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    	final String time = timeFormat.format(ctime);
    	final RkdapPayload payload = new RkdapPayload("ED_25", nowms, jsonObj);
    	final String json = payload.toJSONString();
    	assertEquals("Unexpected payload",
    			"{"+
    				"\"ver\":\"1.1\"," +
    				"\"method\":\"dad_data\"," +
    				"\"data\":[" +
    					"{" +
							"\"period\":\""+date+"T"+time+"\"," +
							"\"id\":\"CDFB_H\"," +
							"\"value\":87" +
						"}," +
    					"{" +
							"\"period\":\""+date+"T"+time+"\"," +
							"\"id\":\"CDFB_B\"," +
							"\"value\":256" +
						"}," +
    					"{" +
    						"\"period\":\""+date+"T"+time+"\"," +
    						"\"id\":\"CDFB_T\"," +
    						"\"value\":18.625" +
						"}," +
    					"{" +
							"\"period\":\""+date+"T"+time+"\"," +
							"\"id\":\"CDFB_L\"," +
							"\"value\":231" +
						"}" +
    				"]," +
    				"\"dad_id\":\"ED_25\"" +
    			"}",
    			json);
	}
}
