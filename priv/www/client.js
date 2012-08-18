/**
 * Simple WebSocket client implementation
 */

document.addEventListener('DOMContentLoaded', function () {

    var input = document.getElementById('publish'),
        sink = document.getElementById('sink');

    sink.style.height = (window.innerHeight - sink.offsetTop - 10).toString() + 'px';

    var writeLine = function (s) {
        var element = document.createElement('div');
        element.innerHTML = s;
        sink.appendChild(element);
    }

    var socket = new WsClient('channel', {
        online: function () {
            writeLine("<div class='ok'>Connection estabilished</div>");
        },
        offline: function (reason) {
            if (reason) {
                writeLine("<div class='fail'>Connection reset because of: " + reason + "</div>");
            }
            else {
                writeLine("<div class='fail'>Connection reset</div>");
            }
        },
        message: function (s) {
            writeLine(s);
        }
    });

    socket.init();

    input.addEventListener('keypress', function (event) {
        if (event.keyCode == 13) {
            socket.send(input.value);
            input.value = null;
        }
    });

});
