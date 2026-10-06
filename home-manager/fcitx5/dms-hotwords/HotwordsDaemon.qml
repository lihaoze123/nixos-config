import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Modules.Plugins
import "config.js" as Config

PluginComponent {
    id: root
    property bool ready: false
    property string failure: ""
    property int nextId: 1
    property var callbacks: ({})
    signal backendStateChanged

    function request(op, payload, callback) {
        if (!ready) {
            callback({ok: false, error: failure || "热词后端尚未启动"});
            return;
        }
        const id = nextId++;
        callbacks[id] = callback;
        backend.write(JSON.stringify(Object.assign({id: id, op: op}, payload)) + "\n");
    }

    Process {
        id: backend
        command: Config.command
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let message;
                try { message = JSON.parse(line); }
                catch (e) { root.failure = "热词后端返回了无效数据"; return; }
                if (message.event === "ready") {
                    root.ready = true;
                    root.failure = "";
                    root.backendStateChanged();
                    return;
                }
                const callback = root.callbacks[message.id];
                delete root.callbacks[message.id];
                if (callback) callback(message);
            }
        }
        onExited: exitCode => {
            root.ready = false;
            root.failure = "热词后端已退出（" + exitCode + "），请重新启用插件";
            const pending = root.callbacks;
            root.callbacks = {};
            for (const id in pending)
                pending[id]({ok: false, error: root.failure});
            root.backendStateChanged();
        }
    }

    IpcHandler {
        target: "vocotypeHotwords"
        function add(): string {
            PopoutService.openDankLauncherV2WithQuery("热+");
            return "VOCOTYPE_HOTWORDS_ADD_OPENED";
        }
        function status(): string {
            return root.ready ? "READY" : root.failure || "STARTING";
        }
    }
}
