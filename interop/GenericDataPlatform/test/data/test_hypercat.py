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

import unittest
import json

from opentrv.data.hypercat import Catalogue, CatalogueItem, Serializer

class TestHypercatSerializer(unittest.TestCase):

    def test_to_json_object(self):
        self.maxDiff = None
        c = Catalogue(
            [
                CatalogueItem("http://a", "Item A"),
                CatalogueItem("http://b", "Item B", "text/csv"),
                CatalogueItem("http://c", "Item C", payload={"n": "c"}),
                CatalogueItem("http://d", "Item D", "text/csv", payload={"n": "d"})
            ],
            "Test Catalogue"
            )
        jo = Serializer().to_json_object(c)
        self.assertDictEqual({
                "catalogue-metadata": [
                    {
                    "rel": "urn:X-hypercat:rels:isContentType",
                    "val": "application/vnd.hypercat.catalogue+json"
                    },
                    {
                    "rel": "urn:X-hypercat:rels:hasDescription:en",
                    "val": "Test Catalogue"
                    }
                ],
                "items": [
                    {
                    "href": "http://a",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "application/vnd.hypercat.catalogue+json"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item A"
                        }
                    ]
                    },
                    {
                    "href": "http://b",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "text/csv"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item B"
                        }
                    ]
                    },
                    {
                    "href": "http://c",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "application/vnd.hypercat.catalogue+json"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item C"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:n",
                        "val": "c"
                        }
                    ]
                    },
                    {
                    "href": "http://d",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "text/csv"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item D"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:n",
                        "val": "d"
                        }
                    ]
                    }
                ]
            }, jo
            )
