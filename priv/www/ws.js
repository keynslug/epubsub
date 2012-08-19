/**
 * WebSocket client wrapper.
 */

function WsClient(target, listener) {
    
    console.debug('Initializing websocket...');

    this.factory = (function () {
        if ('MozWebSocket' in window) {
            return MozWebSocket;
        }
        if ('WebSocket' in window) {
            return WebSocket;
        }
    })();
    
    this.hasTypedArrays = (function () {
        if ('ArrayBuffer' in window) {
            if ('Uint8Array' in window) {
                return true;
            }
        }
        return false;
    })();
    
    this.target = target;
    this.listener = listener;

    var eventNames = ['online', 'offline', 'message'], e;
    for (var i = 0; i < eventNames.length; ++i) {
        e = eventNames[i];
        if (this.listener.hasOwnProperty(e) && typeof(this.listener[e]) === 'function') {
            continue;
        }
        this.listener[e] = function () {
            // blank
        }
    }

};
    
WsClient.prototype.init = function () {

    var here = 'ws://' + window.location.host + this.target;

    console.debug('Estabilishing connection to:', here);
    
    var listener = this.listener;

    var onOpen = function () {
        console.debug("Connection was estabilished.");
        listener.online();
    };
    
    var onClose = function () {
        console.debug("Connection was closed.");
        listener.offline();
    };
    
    var onNotify = function (e) {
        console.debug("Connection received a portion of data.");
        listener.message(WsClient.prototype.receive(e.data), e.origin);
    };

    if (this.factory) {
        try {
            this.socket = new this.factory(here);
            this.socket.binaryType = 'arraybuffer';
            this.socket.onopen = onOpen;
            this.socket.onclose = onClose;
            this.socket.onmessage = onNotify;
        } 
        catch (e) {
            listener.offline('invalid');
        }
    } else {
        listener.offline('unsupported');
    }

};
    
WsClient.prototype.send = function (payload) {
    this.socket.send(payload.toString());
};
    
WsClient.prototype.receive = function (payload) {
    if (typeof(payload) === 'string') {
        return payload;
    }
    else {
        if (this.hasTypedArrays) {
            view = new Uint8Array(payload);
            return String.fromCharCode.call(String, Array.prototype.slice(view));
        }
        else {
            return null;
        }
    }
};
