import QtQuick
import QtQuick.Controls

Item {
    id: root
    // Default size, can be overridden
    width: 300
    height: 40
    
    property real value: 50
    property real minValue: 0
    property real maxValue: 100
    property real step: 1
    // When true, layout aligns content to the left edge instead of centering.
    property bool leftAligned: false
    // Left margin to apply when leftAligned is true
    property int leftMargin: 0
    // previous value for change detection
    property int _prevValue: value
    // flag when value recently changed (used to color the numeric display)
    property bool _valueIsRecent: false
    
    // Allow binding to update value
    onValueChanged: {
        if (value < minValue) value = minValue;
        if (value > maxValue) value = maxValue;
        if (value !== _prevValue) {
            _valueIsRecent = true;
            // reset timer (defined below) to clear the recent flag
            try { valueFlashTimer.stop(); } catch(e) {}
            try { valueFlashTimer.start(); } catch(e) {}
            _prevValue = value;
        }
    }

    Row {
        id: mainRow
        spacing: 15
        anchors.verticalCenter: parent.verticalCenter
        // conditional horizontal anchoring: left-aligned if requested, otherwise centered
        anchors.left: root.leftAligned ? parent.left : undefined
        anchors.leftMargin: root.leftAligned ? root.leftMargin : 0
        anchors.horizontalCenter: root.leftAligned ? undefined : parent.horizontalCenter
        
        // Left Triangle button (rect with border + glyph)
        Rectangle {
            id: leftBtn
            width: 34; height: 34
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            // hovered or pressed -> black fill, white border; otherwise white fill, black border
            border.width: 2
            border.color: (leftMa.containsMouse || leftMa.pressed) ? "white" : "black"
            color: (leftMa.containsMouse || leftMa.pressed) ? "black" : "white"

            Text {
                text: "\u25C4" // ◄
                anchors.centerIn: parent
                font.pixelSize: 18
                color: (leftMa.containsMouse || leftMa.pressed) ? "white" : "black"
            }

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
            // Hover state for the whole slider area
            property bool hovered: false
            
            // Track Line
            // Track background (unfilled)
            Rectangle {
                id: trackBg
                width: parent.width
                height: 8
                // Dim by default, brighten on hover
                color: sliderTrack.hovered ? "#ffffff" : "#bdbdbd"
                anchors.centerIn: parent
                z: 0
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            
            // Click area: clicking on the track sets the value to that position.
            // Placed before the handle so clicks on the handle are handled by the handle's MouseArea.
            MouseArea {
                id: sliderClickMa
                anchors.fill: parent
                hoverEnabled: false
                acceptedButtons: Qt.LeftButton
                onClicked: function(mouse) {
                    try {
                        var px = Math.max(0, Math.min(parent.width, mouse.x));
                        var percent = px / parent.width;
                        var rawVal = root.minValue + percent * (root.maxValue - root.minValue);
                        var newVal = Math.round(rawVal / root.step) * root.step;
                        newVal = Math.max(root.minValue, Math.min(root.maxValue, newVal));
                        root.value = newVal;
                    } catch(e) { console.log('sliderClickMa error', e); }
                }
            }

            // Handle (Circle)
            Rectangle {
                id: handle
                width: 16
                height: 16
                radius: 8
                color: "black"
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

            // Filled portion of the track (left side up to the center of the handle)
            Rectangle {
                id: filledTrack
                height: 2
                color: sliderTrack.hovered ? "#000000" : "#4a4a4a"
                anchors.left: sliderTrack.left
                anchors.verticalCenter: sliderTrack.verticalCenter
                z: 1
                // width follows handle center; clamp to [0, sliderTrack.width]
                width: Math.max(0, Math.min(sliderTrack.width, handle.x + handle.width/2))
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Hover-only MouseArea (doesn't accept clicks so it won't block drag on the handle)
            MouseArea {
                id: sliderHoverMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: { sliderTrack.hovered = true }
                onExited: { sliderTrack.hovered = false }
            }
        }

        // Right Triangle button (rect with border + glyph)
        Rectangle {
            id: rightBtn
            width: 34; height: 34
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            border.width: 2
            border.color: (rightMa.containsMouse || rightMa.pressed) ? "white" : "black"
            color: (rightMa.containsMouse || rightMa.pressed) ? "black" : "white"

            Text {
                text: "\u25BA" // ►
                anchors.centerIn: parent
                font.pixelSize: 18
                color: (rightMa.containsMouse || rightMa.pressed) ? "white" : "black"
            }

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

        // Number Display (black when recently changed, otherwise white)
        Text {
            id: valueText
            text: (root.step < 1) ? Number(root.value).toFixed(3) : Math.round(root.value)
            font.pixelSize: 24
            color: root._valueIsRecent ? "black" : "white"
            width: 60
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Timer to clear recent-value highlight after a short delay
    Timer {
        id: valueFlashTimer
        interval: 800
        repeat: false
        running: false
        onTriggered: { root._valueIsRecent = false }
    }
}
