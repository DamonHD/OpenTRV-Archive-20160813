# Generic data platform interop

The aim of this section is to provide a proof of concept for interoperability
with a generic data platform. It comes in thee parts:

1. A data platform proof of concept that would be deployed on a cloud server
   and that offers a REST API. Note the the implementation provided here is
   a proof of concept and is not designed to support large volumes of data.
2. A bridge component that would be deployed on the OpenTRV concentrator
   and would send data to the data platform in a way that this platform can
   understand.
3. Library code shared by both the platform and the bridge.

The platform and bridge implement a simple provisioning protocol that works as
follows, where:

- `init` is a well known URL on the platform
- `uuid` is the unique identifier of the bridge / concentrator, can typically
  be the MAC address
- `data` is sensor data in SenML format

The current interaction doesn't include the ability to exchange configuration
options between the bridge and the platform.

    Bridge                                                      Platform
    ------                                                      --------
       |    1. GET init                                             |
       |----------------------------------------------------------->|
       |                                   Commissioning URL (comm) |
       |<-----------------------------------------------------------|
       |                                                            |
       |    2. POST comm, uuid                                      |
       |----------------------------------------------------------->|
       |                                          Message URL (msg) |
       |<-----------------------------------------------------------|
       |                                                            |
    +------ 3. Repeat -------------------------------------------------+
    :  |                                                            |  :
    :  |    3.1. POST msg, data                                     |  :
    :  |----------------------------------------------------------->|  :
    :  |                                                            |  :
    +------------------------------------------------------------------+
       |                                                            |

1. bridge GETs well know initialisation URL on platform; the platform replies
   with a JSON object that includes a commissioning URL
2. bridge POSTs key info, including UUID to platform commissioning URL;
   platform replies with a JSON object that includes a message posting URL
3. bridge POSTs data frames in SenML format to the message URL

The platform makes all collected data available over a REST API that follows
the Hypercat standard and as such provides a minimal implementation of the
standard.

## Suggested extensions

At the moment, the bridge does not have to remember the message URL, it can
just re-commission. The side effect of this is that another bridge could POST
to the commissioning URL with the same UUID and be able to masquerade as the
first bridge. To prevent this, we could add the following extensions:

- prevent re-commissioning, thus forcing the bridge to remember the
  commissioning parameters
- exchange security keys on steps 3 and 4 to enable data signing for step 5,
  if connection is over HTTPS

From a functional perspective, a useful extension of this mechanism would be to
allow the bridge to query configuration parameter changes at a regular basis or
to notify the platform of local configuration changes. More information, such
as the Hypercat and configuration URLs could be included in the initialisation
response.

## Run the tests

You can run all unit tests by calling the following command in the same
directory as this file:

    python3 -m unittest discover

## Run the code

The easiest way to run the code for testing is in a `vagrant` virtual machine.
This is managed by the `Vagrantfile` at the root of the repository. Start
the VM and connect to it:

    vagrant up
    vagrant ssh

Start the platform component:

    python3 -m opentrv.platform

Start the bridge concentrator component:

    python3 -m opentrv.concentrator

## Install the code

You can install the code on a clean VM or a RaspberryPi by running the install
script located in the `vm` folder:

    bash wm/install.sh

This will install all dependencies, as well as the `mosquitto` MQTT broker.
if you want to install only the Python code, you can install an editable
version by running the following command:

    sudo pip3 install -e .

When installed this way, any change in the code directory will be picked up
immediately, which also means that if the repository is removed, the code will
stop working. If you'd rather install it permanently, you can use the
following command:

    sudo pip3 intall .
