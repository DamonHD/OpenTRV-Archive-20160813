import logging
import requests
import json

import opentrv.data.senml

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
        r = requests.get(self.platform_url)
        if r.status_code != 200:
            return
        i_resp = json.loads(r.text)
        comm_url = i_resp.commission
        r = requests.post(comm_url, data={'uuid': ''})
        c_resp = json.loads(r.text)
        self.message_url = c_resp.message_url

    def on_message(self, records):
        """
        Message callback function called by the upstream record generator.
        The HTTP client formats the given record list into SenML and POSTs
        to the online service.
        """
        if records is not None:
            self.logger.debug("Records: "+str(records))
            payload = self.serializer.to_json(records)
            r = requests.post(self.message_url, data=payload)
        else:
            self.logger.debug("Empty record set")
