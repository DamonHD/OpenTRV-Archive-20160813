import json
import random
import string
import logging
from flask import Flask, jsonify, abort, make_response, url_for, request

import opentrv.data.senml
import opentrv.data.hypercat
from opentrv.platform.model import Concentrators, Devices, Sensors, Series

app = Flask(__name__)

concs = Concentrators()

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "version": "0.1.0",
        "commissioning_url": url_for('commission')
        })

@app.route('/commission', methods=['POST'])
def commission():
    if not request.json:
        app.logger.error("Request is not JSON")
        abort(400)
    if not 'uuid' in request.json:
        app.logger.error("Unexpected request content: "+str(request.json))
        abort(400)
    uuid = request.json['uuid']
    c = concs.find_by_uuid(uuid)
    if c is None:
        conc_msg_key = ''.join(random.SystemRandom().choice(
            string.ascii_letters + string.digits
            ) for _ in range(16))
        app.logger.info("Commissioning concentrator {0} with key {1}".format(uuid, conc_msg_key))
        c = {
            "uuid": uuid,
            "mkey": conc_msg_key,
            "message_url": url_for('post_message', mkey=conc_msg_key)
        }
        concs.add(c)
        concs.save()
    else:
        app.logger.info("Retrieving concentrator {0} with key {1}".format(c["uuid"], c["mkey"]))
    return jsonify(c)

@app.route('/d/<string:mkey>', methods=['POST'])
def post_message(mkey):
    if not request.json:
        abort(400)
    c = concs.find_by_mkey(mkey)
    if c is None:
        abbort(404)
    app.logger.debug(request.json)
    devices = Devices(c)
    senml_ser = opentrv.data.senml.Serializer()
    records = senml_ser.from_json_object(request.json)
    for r in records:
        d = devices.find_by_topic(r.topic)
        if d is None:
            d = devices.add_topic(r.topic)
            app.logger.debug("Adding device {0}/{1}".format(d["mkey"], d["bn"]))
        else:
            app.logger.debug("Retrieving device {0}/{1}".format(d["mkey"], d["bn"]))
        sensors = Sensors(d)
        s = sensors.find_by_record(r)
        if s is None:
            s = sensors.add_record(r)
            app.logger.debug("Adding sensor {0}/{1}/{2}".format(s["mkey"], s["bn"], s["n"]))
        else:
            app.logger.debug("Retrieving sensor {0}/{1}/{2}".format(s["mkey"], s["bn"], s["n"]))
        sensors.save()
        ts = Series(s)
        ts.add_record(r)
        ts.save()
    devices.save()
    return jsonify({'ok': True}), 201

@app.route('/cat', methods=['GET'])
def get_concentrators():
    cat = opentrv.data.hypercat.Catalogue(
        [opentrv.data.hypercat.CatalogueItem(
            url_for('get_concentrator', mkey=c['mkey']),
            "Concentrator {0}".format(c['mkey']),
            payload = c
            ) for c in concs.find_all()]
        )
    return opentrv.data.hypercat.Serializer().to_json(cat)

@app.route('/d/<string:mkey>', methods=['GET'])
def get_concentrator(mkey):
    c = concs.find_by_mkey(mkey)
    if c is None:
        abort(404)
    devices = Devices(c)
    cat = opentrv.data.hypercat.Catalogue(
        [opentrv.data.hypercat.CatalogueItem(
            url_for('get_device', mkey=d['mkey'], bn=d['bn']),
            "Device {0}/{1}".format(d['mkey'], d['bn']),
            payload = d
            ) for d in devices.find_all()]
        )
    return opentrv.data.hypercat.Serializer().to_json(cat)

@app.route('/d/<string:mkey>/<string:bn>', methods=['GET'])
def get_device(mkey, bn):
    c = concs.find_by_mkey(mkey)
    if c is None:
        abort(404)
    devices = Devices(c)
    d = devices.find_by_bn(bn)
    if d is None:
        abort(404)
    sensors = Sensors(d)
    cat = opentrv.data.hypercat.Catalogue(
        [opentrv.data.hypercat.CatalogueItem(
            url_for('get_sensor', mkey=s['mkey'], bn=s['bn'], n=s['n']),
            "Sensor {0}/{1}/{2}".format(s['mkey'], s['bn'], s['n']),
            content_type = opentrv.data.senml.MIME_TYPE,
            payload = s
            ) for s in sensors.find_all()]
        )
    return opentrv.data.hypercat.Serializer().to_json(cat)

@app.route('/d/<string:mkey>/<string:bn>/<string:n>', methods=['GET'])
def get_sensor(mkey, bn, n):
    c = concs.find_by_mkey(mkey)
    if c is None:
        abort(404)
    devices = Devices(c)
    d = devices.find_by_bn(bn)
    if d is None:
        abort(404)
    sensors = Sensors(d)
    s = sensors.find_by_n(n)
    if s is None:
        abort(404)
    ts = Series(s)
    return opentrv.data.senml.Serializer().to_json(ts.find_all_records())

@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({'error': 'Not found'}), 404)

@app.errorhandler(400)
def bad_request(error):
    return make_response(jsonify({'error': 'Bad request'}), 400)

@app.errorhandler(403)
def bad_request(error):
    return make_response(jsonify({'error': 'Forbidden'}), 403)
