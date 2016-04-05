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

import os.path
import json
import opentrv.data.storage

TOMBSTONE = "NaR"

class Model(object):
    """
    A very basic model object that uses JSON files to store the data.
    It can index data items according to multiple keys in the data and assumes
    each of those keys uniquely identify a record. It will make not attempt
    to check inconsistencies if different items have been given the same keys
    potentially resulting in items falling out of the index.
    """
    def __init__(self, domain, name, keys=[], auto_load=True):
        self.domain = domain
        self.name = name
        self.keys = keys
        opentrv.data.storage.mkdir(domain)
        self.path = opentrv.data.storage.path(os.path.join(domain, "{0}.json".format(name)))
        self.data = []
        self.indices = { k: {} for k in self.keys }
        if auto_load:
            self.load()

    def load(self):
        if os.path.exists(self.path):
            with open(self.path, 'r') as f:
                self.data = json.load(f)
            self._index_all()

    def _index_all(self):
        for (i, record) in enumerate(self.data):
            self._index(i, record)

    def _index(self, i, record):
        for k in self.keys:
            idx = record[k]
            self.indices[k][idx] = i

    def save(self):
        with open(self.path, 'w') as f:
            json.dump(self.data, f)

    def add(self, record):
        i = len(self.data)
        self.data.append(record)
        self._index(i, record)
        return record

    def normalise(self, record):
        if record is None or record == TOMBSTONE:
            return None
        else:
            return record

    def find_all(self):
        return self.data

    def _find_idx_by_key(self, key_name, key_value):
        idx = self.indices[key_name]
        if key_value in idx:
            return idx[key_value]
        else:
            return None

    def find_by_key(self, key_name, key_value):
        idx = self._find_idx_by_key(key_name, key_value)
        if idx is not None:
            return self.normalise(self.data[idx])
        else:
            return None

    def del_by_key(self, key_name, key_value):
        idx = self._find_idx_by_key(key_name, key_value)
        if idx is not None:
            old_data = self.normalise(self.data[idx])
            if old_data is not None:
                self.data[idx] = TOMBSTONE
                for k in self.keys:
                    self._del_key_for_idx(k, old_data[k], idx)

    def _del_key_for_idx(self, key_name, key_value, idx):
        sidx = self._find_idx_by_key(key_name, key_value)
        if sidx is not None and sidx == idx:
            del self.indices[key_name][key_value]

    def truncate(self):
        self.data = []
        self.indices = { k: {} for k in self.keys }

    # Container implementation

    def __len__(self):
        return len([d for d in self.data if (d is not None and d != TOMBSTONE)])
