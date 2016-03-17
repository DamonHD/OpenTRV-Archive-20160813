# The OpenTRV project licenses this file to you
# under the Apache Licence, Version 2.0 (the "Licence");
# you may not use this file except in compliance
# with the Licence. You may obtain a copy of the Licence at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Licence is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the Licence for the
# specific language governing permissions and limitations
# under the Licence.
#
# Author(s) / Copyright (s): Bruno Girin 2016

import logging
import requests
import json
import uuid
from urllib.parse import urljoin

import opentrv.data.senml

REQUEST_HEADERS = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

class Client(object):
    """
    HTTP POST client. This object acts as a sink for a messge generator and
    publishes everything to a HTTP/S URL using HTTP POST.
    """

    def __init__(self, url):
        """
        Initialise the client with the given URL.
        """
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initialising HTTP client to: "+str(url))
        self.platform_url = url
        self.message_url = ""
        self.serializer = opentrv.data.senml.Serializer()

    # Utility methods

    def get(self, url):
        """
        Perform a GET request against the given URL and handle error conditions
        """
        try:
            furl = urljoin(self.platform_url, url)
            r = requests.get(furl, headers=REQUEST_HEADERS)
        except:
            self.logger.error("Could not connect to URL {0}".format(furl))
            raise
        if r.status_code != 200:
            self.logger.error("URL {0} returned code {1}".format(furl, r.status_code))
            raise Exception("URL {0} returned code {1}".format(furl, r.status_code))
        try:
            g_resp = json.loads(r.text)
        except ValueError:
            self.logger.error("URL {0} returned non-JSON payload: {1}".format(furl, r.text))
            raise
        return g_resp

    def post(self, url, data):
        """
        Perform a POST request against the given URL with the given data payload
        and handle error conditions
        """
        try:
            furl = urljoin(self.platform_url, url)
            r = requests.post(furl, headers=REQUEST_HEADERS, data=data)
        except:
            self.logger.error("Could not connect to URL {0}".format(furl))
            raise
        if r.status_code not in [200, 201, 202]:
            self.logger.error("URL {0} returned code {1}".format(furl, r.status_code))
            raise Exception("URL {0} returned code {1}".format(furl, r.status_code))
        try:
            p_resp = json.loads(r.text)
        except ValueError:
            self.logger.error("URL {0} returned non-JSON payload: {1}".format(furl, r.text))
            raise
        return p_resp

    # Life-cycle methods

    def commission(self):
        """
        Commission the client by sending a GET request to the given URL.
        The client expects the URL to reply with a JSON object that provides
        a commissioning URL. The client then sends a POST request to the
        commissioning URL giving a UUID as parameter. If the service responds
        with HTPP 200, the body should contain a message URL that is unique
        to that client. The service may respond with HTTP 403 if that client
        was already commissioned.
        """
        self.logger.debug("Commissioning HTTP client")
        i_resp = self.get(self.platform_url)
        comm_url = i_resp["commissioning_url"]
        c_resp = self.post(comm_url, data=json.dumps({'uuid': hex(uuid.getnode())}))
        self.message_url = c_resp["message_url"]

    def on_message(self, records):
        """
        Message callback function called by the upstream record generator.
        The HTTP client formats the given record list into SenML and POSTs
        to the online service.
        """
        if records is not None:
            self.logger.debug("Records: "+str(records))
            payload = self.serializer.to_json(records)
            self.post(self.message_url, payload)
        else:
            self.logger.debug("Empty record set")
