from opentrv.data.model import Model

DOMAIN = "platform"

CONC_MODEL_NAME = "concentrators"
CONC_KEY_UUID = "uuid"
CONC_KEY_MKEY = "mkey"

DEVICES_MODEL_NAME = "devices"
DEVICES_KEY_BN = "bn"
DEVICES_TOPIC_SEP = "_"

SENSORS_MODEL_NAME = "sensors"
SENSORS_KEY_N = "n"

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

class Devices(Model):
    def __init__(self, concentrator):
        self.mkey = concentrator[CONC_KEY_MKEY]
        super(Devices, self).__init__(
            DOMAIN, "_".join([self.mkey, DEVICES_MODEL_NAME]),
            [DEVICES_KEY_BN]
            )

    def find_by_bn(self, bn):
        return self.find_by_key(DEVICES_KEY_BN, bn)

    def find_by_topic(self, topic):
        return self.find_by_bn(topic.path(sep=DEVICES_TOPIC_SEP))

    def add_topic(self, topic):
        return self.add({"mkey": self.mkey, "bn": topic.path(sep=DEVICES_TOPIC_SEP)})

class Sensors(Model):
    def __init__(self, device):
        self.mkey = device[CONC_KEY_MKEY]
        self.bn = device[DEVICES_KEY_BN]
        super(Sensors, self).__init__(
            DOMAIN, "_".join([self.mkey, self.bn, SENSORS_MODEL_NAME]),
            [SENSORS_KEY_N]
            )

    def find_by_n(self, n):
        return self.find_by_key(SENSORS_KEY_N, n)

    def find_by_record(self, record):
        return self.find_by_n(record.name)

    def add_record(self, record):
        s = {"mkey": self.mkey, "bn": self.bn, "n": record.name}
        if record.unit is not None:
            s["u"] = record.unit
        return self.add(s)