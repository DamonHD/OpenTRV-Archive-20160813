from opentrv.data.model import Model

DOMAIN = "platform"

DEVICES_MODEL_NAME = "devices"
DEVICES_KEY_UUID = "uuid"
DEVICES_KEY_MKEY = "mkey"

class Devices(Model):
    def __init__(self):
        super(Devices, self).__init__(
            DOMAIN, DEVICES_MODEL_NAME,
            [DEVICES_KEY_UUID, DEVICES_KEY_MKEY]
            )

    def find_by_uuid(self, uuid):
        return self.find_by_key(DEVICES_KEY_UUID, uuid)

    def find_by_mkey(self, mkey):
        return self.find_by_key(DEVICES_KEY_MKEY, mkey)
