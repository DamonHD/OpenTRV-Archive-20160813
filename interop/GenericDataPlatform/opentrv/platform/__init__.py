import random
import string
import logging
from flask import Flask, jsonify, abort, make_response, url_for, request

app = Flask(__name__)

devices = {}

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "version": "0.1.0",
        "commissioning_url": url_for('commission_device')
        })

@app.route('/commission', methods=['POST'])
def commission_device():
    if not request.json:
        app.logger.error("Request is not JSON")
        abort(400)
    if not 'uuid' in request.json:
        app.logger.error("Unexpected request content: "+str(request.json))
        abort(400)
    uuid = request.json['uuid']
    device_msg_key = ''.join(random.SystemRandom().choice(
        string.ascii_letters + string.digits
        ) for _ in range(16))
    app.logger.info("Commissioning device {0} with key {1}".format(uuid, device_msg_key))
    # Associate a device UUID to a message key
    # TODO: ensure a given device can't be commissioned twice
    devices[uuid] = device_msg_key
    return jsonify({
        "message_key": device_msg_key,
        "message_url": url_for('post_message', device_key=device_msg_key)
        })

@app.route('/data/<string:device_key>', methods=['POST'])
def post_message(device_key):
    if not request.json:
        abort(400)
    app.logger.debug(request.json)
    return jsonify({'ok': True}), 201

@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({'error': 'Not found'}), 404)

@app.errorhandler(400)
def bad_request(error):
    return make_response(jsonify({'error': 'Bad request'}), 400)
