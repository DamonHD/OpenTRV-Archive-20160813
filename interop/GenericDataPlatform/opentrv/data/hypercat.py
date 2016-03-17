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

import json

# Constants for the Hypercat payload
MIME_TYPE = "application/vnd.hypercat.catalogue+json"

KEY_CAT_ITEMS = "items"
KEY_CAT_META = "catalogue-metadata"

KEY_OBJ_HREF = "href"
KEY_OBJ_META = "item-metadata"

KEY_META_REL = "rel"
KEY_META_VAL = "val"

# Generic rel template
REL_GENERIC = "urn:X-hypercat:rels:{key}"
REL_DESCRIPTION           = REL_GENERIC.format(key="hasDescription:{lang}")
REL_DESCRIPTION_DEFAULT   = REL_DESCRIPTION.format(lang='en')
REL_CONTENT_TYPE          = REL_GENERIC.format(key="isContentType")
REL_HOMEPAGE              = REL_GENERIC.format(key="hasHomepage")
REL_CONTAINS_CONTENT_TYPE = REL_GENERIC.format(key="containsContentType")
REL_SUPPORTS_SEARCH       = REL_GENERIC.format(key="supportsSearch")


class Catalogue(object):
    def __init__(self, items, description="", content_type=MIME_TYPE):
        self.items = items
        self.description = description
        self.content_type = content_type

class CatalogueItem(object):
    def __init__(self, href, description="", content_type=MIME_TYPE, payload={}):
        self.href = href
        self.description = description
        self.content_type = content_type
        self.payload = payload

class Serializer(object):
    def _item_to_json_object(self, item):
        meta_list = [
            {
                KEY_META_REL: REL_CONTENT_TYPE,
                KEY_META_VAL: item.content_type
            },
            {
                KEY_META_REL: REL_DESCRIPTION_DEFAULT,
                KEY_META_VAL: item.description
            }
        ]
        meta_list.extend([{
            KEY_META_REL: REL_GENERIC.format(key=k), KEY_META_VAL: v
            } for (k, v) in item.payload.items()])
        return {
            KEY_OBJ_HREF: item.href,
            KEY_OBJ_META: meta_list
        }

    def to_json_object(self, cat):
        return {
            KEY_CAT_META: [
                {
                    KEY_META_REL: REL_CONTENT_TYPE,
                    KEY_META_VAL: MIME_TYPE
                },
                {
                    KEY_META_REL: REL_DESCRIPTION_DEFAULT,
                    KEY_META_VAL: cat.description
                }
            ],
            KEY_CAT_ITEMS: [
                self._item_to_json_object(item) for item in cat.items
            ]
        }

    def to_json(self, cat):
        return json.dumps(self.to_json_object(cat))
