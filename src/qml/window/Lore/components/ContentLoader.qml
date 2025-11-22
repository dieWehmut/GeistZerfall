import QtQuick

// ContentLoader.qml - 内容加载器
Item {
    id: root

    property var contentData: null

    onContentDataChanged: {
        console.log("ContentLoader: contentData changed", contentData ? JSON.stringify(contentData) : "null");
        loadContent();
    }

    function loadContent() {
        console.log("ContentLoader: loadContent called");
        // 清空之前的内容
        for (var i = loader.children.length - 1; i >= 0; i--) {
            loader.children[i].destroy();
        }

        if (!contentData) {
            console.log("ContentLoader: no content data");
            return;
        }

        console.log("ContentLoader: loading type", contentData.type);

        var component = null;
        var qmlFile = "";

        // 根据类型加载对应的 QML
        switch (contentData.type) {
            case "text":
                qmlFile = "../contentShow/ContentText.qml";
                break;
                case "image":
                qmlFile = "../contentShow/ContentImage.qml";
                break;
            case "animation":
                qmlFile = "../contentShow/Animation.qml";
                break;
            default:
                console.log("ContentLoader: unknown content type", contentData.type);
                return;
        }

        component = Qt.createComponent(qmlFile);
        if (component.status === Component.Ready) {
            createContent(component);
        } else if (component.status === Component.Error) {
            console.log("ContentLoader: error loading component", component.errorString());
        } else {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    createContent(component);
                }
            });
        }
    }

    function createContent(component) {
        console.log("ContentLoader: creating content object");
        var obj = component.createObject(loader, {
            "contentData": contentData
        });
        if (obj === null) {
            console.log("ContentLoader: error creating object");
        } else {
            console.log("ContentLoader: successfully created content object");
        }
    }

    Item {
        id: loader
        anchors.fill: parent
    }
}
