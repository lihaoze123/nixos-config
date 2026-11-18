import QtQuick
import qs.Services

Item {
    id: root
    property var pluginService: null
    property string pluginId: "vocotypeHotwords"
    property string trigger: "热+"
    readonly property var daemon: pluginService ? pluginService.pluginDaemonInstances[pluginId] || null : null
    property string cachedQuery: ""
    property var cached: null
    property string wanted: ""
    property bool pending: false
    signal itemsChanged

    function refresh() {
        if (pluginService) pluginService.requestLauncherUpdate(pluginId);
    }
    Connections {
        target: root.daemon
        function onBackendStateChanged() {
            root.cached = null;
            root.pending = false;
            root.refresh();
        }
    }
    function info(title, detail) {
        return {id: "info:" + title, name: title, comment: detail || "", icon: "material:info",
                action: "none", categories: ["语音热词"], _preScored: 1000};
    }
    function pump() {
        if (pending || !wanted || !daemon || !daemon.ready) return;
        const query = wanted;
        wanted = "";
        pending = true;
        daemon.request("preview", {query: query}, message => {
            pending = false;
            cachedQuery = query;
            cached = message;
            if (wanted && wanted !== query) pump();
            else { wanted = ""; refresh(); }
        });
    }
    function getItems(query) {
        const text = (query || "").trim();
        if (!text) {
            cached = null;
            wanted = "";
            return [info("输入要添加的热词", "热+NixOS　或　热+NixOS = 尼克斯 | nix os")];
        }
        if (!daemon || !daemon.ready)
            return [info("热词后端未就绪", daemon ? daemon.failure : "请在插件设置中启用「语音热词」")];
        if (!cached || cachedQuery !== text) {
            wanted = text;
            pump();
            return [info("正在检查词库…", text)];
        }
        if (!cached.ok) return [info("无法添加", cached.error)];
        if (cached.existing)
            return [info("已存在：" + cached.existing.canonical,
                         "不会重复添加；修改别名或启用已有词的热词选项，请使用 VoCoType 设置中心")];
        return [{id: "save:" + text, name: "保存热词：" + cached.word,
                 comment: (cached.aliases.length ? "纠错别名：" + cached.aliases.join(" / ") + " · " : "")
                          + "热词与保护已启用 · 下一次听写使用",
                 icon: "material:save", categories: ["语音热词"], _preScored: 1000,
                 action: "save", query: text, fingerprint: cached.fingerprint},
                Object.assign(info("词库位置", cached.path), {_preScored: 999})];
    }
    function executeItem(item) {
        if (!item || item.action !== "save" || !daemon) return;
        daemon.request("save", {query: item.query, fingerprint: item.fingerprint}, message => {
            cached = null;
            if (!message.ok) ToastService.showError("热词未保存", message.error);
            else if (message.status === "already_exists") ToastService.showInfo("热词已存在，无需重复添加");
            else ToastService.showInfo("已添加热词：" + message.word, "下一次听写使用，无需在豆包控制台再添加");
            refresh();
        });
    }
}
