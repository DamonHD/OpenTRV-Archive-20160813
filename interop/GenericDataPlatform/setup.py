#!/usr/bin/env python3

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

from setuptools import setup

setup(
    name="opentrv-interop",
    version="0.1",
    description="Interoperability tools and generic data platform reference implementation",
    author="Bruno Girin, OpenTRV",
    author_email="brunogirin@gmail.com",
    packages=[
        'opentrv',
        'opentrv.data', 'opentrv.data.storage', 'opentrv.data.model',
        'opentrv.concentrator',
        'opentrv.platform',
    ],
    long_description="""
    Generic data platform interop implements a MQTT to HTTP bridge for OpenTRV
    data as well as a reference data platform API that includes commissioning
    support to reduce the amount of configuration required to forward any
    OpenTRV data to upstream data platforms.
    """,
    classifiers=[
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3 :: Only",
        "Development Status :: 2 - Pre-Alpha",
        "Framework :: Flask",
        "Intended Audience :: Developers",
        "Natural Language :: English",
        "Operating System :: POSIX :: Linux"
    ],
    keywords='MQTT REST IoT',
    license="Apache",
    install_requires=[
        'setuptools',
        'mosquitto'
    ],
    )