from opentrv.data.model import Model

DOMAIN = "platform"

CONC_MODEL_NAME = "concentrators"
CONC_KEY_UUID = "uuid"
CONC_KEY_MKEY = "mkey"

class Concentrators(Model):
    def __init__(self):
        super(Concentrators, self).__init__(
            DOMAIN, CONC_MODEL_NAME,
            [CONC_KEY_UUID, CONC_KEY_MKEY]
            )

    def find_by_uuid(self, uuid):
        return self.find_by_key(CONC_KEY_UUID, uuid)

    def find_by_mkey(self, mkey):
        return self.find_by_key(CONC_KEY_MKEY, mkey)
