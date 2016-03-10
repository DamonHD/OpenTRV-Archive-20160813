import logging
import requests

class Client(object):
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.logger.debug("Initialising HTTP client")
        self.platform_url = ""
        self.message_url = ""

    def commission(self):
        self.logger.debug("Commissioning HTTP client")
        r = requests.get(self.platform_url)
        if r.status_code != 200:
            return
        i_resp = json.loads(r.text)
        comm_url = i_resp.commission
        r = requests.post(comm_url, data={'uuid': ''})
        c_resp = json.loads(r.text)
        self.message_url = c_resp.message_url

    def on_message(self, msg):
        self.logger.debug("Message: "+str(msg))
        r = requests.post(self.message_url, data=msg)
