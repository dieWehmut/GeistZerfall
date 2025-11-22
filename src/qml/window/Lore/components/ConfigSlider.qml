import QtQuick
import QtQuick.Controls

Item {
    id: root
    // Default size, can be overridden
    width: 300
    height: 40
    
    property int value: 50
    property int minValue: 0
    property int maxValue: 100
    property int step: 1
    
    // Allow binding to update value
    onValueChanged: {
        if (value < minValue) value = minValue;
        if (value > maxValue) value = maxValue;
    }

    Row {
        anchors.centerIn: parent
        spacing: 15
        
        // Left Triangle
        Text {
            text: "\u25C4" // ◄
            font.pixelSize: 24
            color: leftMa.containsMouse ? "#cccccc" : "white"
            anchors.verticalCenter: parent.verticalCenter
            
            MouseArea {
                id: leftMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.value = Math.max(root.minValue, root.value - root.step)
                }
            }
        }

        // Slider Area
        Item {
            id: sliderTrack
            width: 150 // Fixed width for the track part within the component
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            
            // Track Line
            Rectangle {
                width: parent.width
                height: 2
                color: "white"
                anchors.centerIn: parent
            }
            
            // Handle (Circle)
            Rectangle {
                id: handle
                width: 16
                height: 16
                radius: 8
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                
                // Calculate x based on value
                x: (root.value - root.minValue) / (root.maxValue - root.minValue) * (sliderTrack.width - width)
                
                onXChanged: {
                    if (dragArea.drag.active) {
                        var percent = x / (sliderTrack.width - width)
                        var rawVal = root.minValue + percent * (root.maxValue - root.minValue)
                        var newVal = Math.round(rawVal / root.step) * root.step
                        if (newVal !== root.value) {
                            root.value = newVal
                        }
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    anchors.margins: -10 // Larger hit area
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: sliderTrack.width - parent.width
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // Right Triangle
        Text {
            text: "\u25BA" // ►
            font.pixelSize: 24
            color: rightMa.containsMouse ? "#cccccc" : "white"
            anchors.verticalCenter: parent.verticalCenter
            
            MouseArea {
                id: rightMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.value = Math.min(root.maxValue, root.value + root.step)
                }
            }
        }

        // Number Display
        Text {
            text: root.value
            font.pixelSize: 24
            color: "white"
            width: 40
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
