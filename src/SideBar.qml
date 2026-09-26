import QtQml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects  // Qt6: moved from QtGraphicalEffects
import QtCore  // Qt6: Settings moved from Qt.labs.settings
import CCTV_Viewer.Core 1.0
import CCTV_Viewer.Themes 1.0
import CCTV_Viewer.Utils 1.0

FocusScope {
    id: rootSideBar

    enum State {
        Compact,
        Popup,
        Expanded
    }

    implicitWidth: Context.config.fullScreen && state !== SideBar.Expanded ? 0 :
                   state === SideBar.Expanded ? container.implicitWidth : compactWidth
    implicitHeight: flickable.contentHeight

    property int state: SideBar.Compact
    property int currentViewportIndex: Utils.currentLayout().focusIndex

    // Constants
    readonly property real compactWidth: 48
    readonly property real expandedWidth: 230

    onCurrentViewportIndexChanged: {
        if (rootSideBar.currentViewportIndex < 0  && state === SideBar.Popup) {
            rootSideBar.forceActiveFocus();
        }
    }
    Keys.onPressed: {
        if (event.key === Qt.Key_Escape && state === SideBar.Popup) {
            state = SideBar.Compact;
        }
    }
    Component.onCompleted: {
        state = sideBarSettings.compact ? SideBar.Compact : SideBar.Expanded;

        rootSideBar.stateChanged.connect(() => {
            sideBarSettings.compact = (state !== SideBar.Expanded);
        });
    }

    Settings {
        id: sideBarSettings

        fileName: Context.config.fileName
        category: "SideBar"

        property bool compact: true

        // Items settings
        property string windowDivision
        property string aspectRatios
        property string itemsState
    }

    Item {
        id: container

        opacity: Context.config.fullScreen && rootSideBar.state === SideBar.Compact ? 0 :
                 rootSideBar.state === SideBar.Popup ? 0.6 : 1
        implicitWidth: rootSideBar.state === SideBar.Compact ? compactWidth : expandedWidth
        implicitHeight: rootSideBar.height
        anchors.right: parent.right

        Behavior on opacity {
            enabled: !Context.config.fullScreen || rootSideBar.state !== SideBar.Compact

            OpacityAnimator {
                duration: 1500
            }
        }

        Behavior on implicitWidth {
            PropertyAnimation {
                easing.type: Easing.InSine
                duration: 250
            }
        }

        MouseArea {
            hoverEnabled: true
            anchors.fill: parent

            onContainsMouseChanged: {
                if (containsMouse) {
                    delayOpenningTimer.start();
                    delayAutoCollapseTimer.stop();
                } else {
                    delayOpenningTimer.stop();
                    delayAutoCollapseTimer.start();
                }
            }

            Timer {
                id: delayOpenningTimer

                interval: 150

                onTriggered: {
                    if (rootSideBar.state === SideBar.Compact) {
                        rootSideBar.state = SideBar.Popup
                        rootSideBar.forceActiveFocus();
                    }
                }
            }
            Timer {
                id: delayAutoCollapseTimer

                interval: 30000  // 30 seconds before auto-collapse

                onTriggered: {
                    if (!rootWindowSettings.sidebarPinned &&
                        rootWindowSettings.sidebarAutoCollapse &&
                        rootSideBar.state === SideBar.Popup) {
                        rootSideBar.state = SideBar.Compact;
                    }
                }
            }

            Rectangle {
                id: containerBackground

                color: rootWindow.palette.dark
                width: container.width
                height: container.height
            }

            Flickable {
                id: flickable

                contentHeight: Math.max(parent.height, layout.implicitHeight + footer.implicitHeight + layout.verticalMargins * 2)
                anchors.fill: parent

                ColumnLayout {
                    id: layout

                    spacing: 0

                    width: parent.width
                    height: Math.max(implicitHeight, parent.height - footerRow.height - verticalMargins * 2)

                    anchors.top: parent.top
                    anchors.topMargin: verticalMargins

                    readonly property real verticalMargins: 7

                    SideBarItem {
                        id: header

                        icon: "qrc:/images/menu.svg"
                        title: qsTr("Cameras")

                        Layout.fillWidth: true

                        Item {
                            implicitWidth: 200
                            implicitHeight: 160

                            Column {
                                id: headerContent
                                anchors.centerIn: parent
                                spacing: 10
                                width: parent.width

                                // Circular avatar - centered
                                Rectangle {
                                    id: avatarContainer
                                    width: 96
                                    height: 96
                                    radius: 48
                                    color: "#333"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    
                                    // Circular clipping using layer
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: avatarContainer.width
                                            height: avatarContainer.height
                                            radius: avatarContainer.radius
                                        }
                                    }
                                    
                                    Image {
                                        id: avatarImage
                                        source: SystemInfo.userAvatar
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                // Username@hostname - centered
                                Text {
                                    id: userInfoText
                                    text: SystemInfo.userName + "@" + SystemInfo.hostName
                                    color: "white"
                                    font.pointSize: rootWindow.font.pointSize * 1.3
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }

                    SideBarItem {
                        objectName: "recordings"
                        icon: "qrc:/images/menu-recordings.svg"
                        title: qsTr("Recordings")

                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent

                            Button {
                                text: qsTr("Review")
                                Layout.fillWidth: true
                                onClicked: {
                                    // Use systemd-run --user to bypass snap confinement issues
                                    ProcessLauncher.launch("systemd-run", [
                                        "--user",
                                        "--no-block",
                                        "chromium-browser",
                                        "--password-store=basic",
                                        "--start-fullscreen",
                                        "--app=http://localhost:5000/review"
                                    ])
                                }
                            }
                        }
                    }

                    SideBarItem {
                        objectName: "tools"
                        icon: "qrc:/images/menu-tools.svg"
                        title: qsTr("Tools")
                        locked: rootWindowSettings.lockToolsPanel

                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent

                            GroupBox {
                                title: qsTr("Window division")
                                palette.windowText: "white"
                                opacity: enabled ? 1.0 : 0.5

                                // Disable controls when edit mode is off or when one of the viewports is in full-screen mode.
                                enabled: rootWindowSettings.editMode && !(Utils.currentLayout().fullScreenIndex >= 0)

                                Layout.fillWidth: true

                                GridLayout {
                                    columns: 2
                                    anchors.fill: parent

                                    ListModel {
                                        id: divisionModel

                                        ListElement {
                                            size: "1x1"
                                        }
                                        ListElement {
                                            size: "2x2"
                                        }
                                        ListElement {
                                            size: "3x3"
                                        }
                                        ListElement {
                                            size: "4x4"
                                        }

                                        Component.onCompleted: {
                                            fromJSValue(sideBarSettings.windowDivision);

                                            divisionModel.dataChanged.connect(() => {
                                                sideBarSettings.windowDivision = JSON.stringify(toJSValue());
                                            });
                                        }

                                        function fromJSValue(model) {
                                            var arr;

                                            try {
                                                if (!model.isEmpty()) {
                                                    arr = JSON.parse(model);
                                                }
                                            } catch(err) {
                                                Utils.log_error(qsTr("Error reading configuration!"));
                                            }

                                            if (arr instanceof Array) {
                                                for (var i = 0; i < arr.length; ++i) {
                                                    divisionModel.set(i, arr[i]);
                                                }
                                            }
                                        }

                                        function toJSValue() {
                                            var arr = [];
                                            for (var i = 0; i < divisionModel.count; ++i) {
                                                arr[i] = divisionModel.get(i)
                                            }
                                            return arr;
                                        }
                                    }

                                    Repeater {
                                        model: divisionModel
                                        delegate: Item {
                                            id: divisionItem

                                            implicitWidth: divisionTextField.implicitWidth
                                            implicitHeight: divisionTextField.implicitHeight

                                            Layout.fillWidth: true

                                            Keys.onEscapePressed: {
                                                event.accepted = divisionTextField.visible;
                                                divisionTextField.cancel();
                                            }
                                            Keys.onPressed: {
                                                if (event.key === Qt.Key_F2) {
                                                    divisionTextField.edit();
                                                }
                                            }

                                            Button {
                                                text: size
                                                highlighted: {
                                                    Utils.currentModel().size === str2size(size);
                                                }
                                                anchors.fill: parent

                                                onClicked: Utils.currentModel().size = str2size(size)
                                                onPressAndHold: divisionTextField.edit()

                                                ToolTip.delay: Compact.toolTipDelay
                                                ToolTip.timeout: Compact.toolTipTimeout
                                                ToolTip.visible: hovered
                                                ToolTip.text: qsTr("Press and hold to enter edit mode")
                                            }

                                            TextField {
                                                id: divisionTextField

                                                visible: false
                                                anchors.fill: parent
                                                horizontalAlignment: TextInput.AlignHCenter
                                                selectByMouse: true

                                                onEditingFinished: {
                                                    visible = false;
                                                    if(str2size(text)) {
                                                        size = text;
                                                    }
                                                }

                                                function edit() {
                                                    text = size;
                                                    visible = true;
                                                    forceActiveFocus();
                                                }

                                                function cancel() {
                                                    text = size;
                                                    visible = false;
                                                }
                                            }

                                            function str2size(str) {
                                                var separatorTr = qsTr("x");
                                                var regexp = new RegExp("^[1-9][x%1][1-9]$".arg(separatorTr));
                                                if (regexp.test(str)) {
                                                    var size = str.split(new RegExp("[x%1]".arg(separatorTr)));
                                                    return Qt.size(size[0], size[1]);
                                                }

                                                return null;
                                            }
                                        }
                                    }
                                }
                            }

                            GroupBox {
                                title: qsTr("Geometry")
                                palette.windowText: "white"

                                Layout.fillWidth: true

                                GridLayout {
                                    id: geometryLayout

                                    columns: 2
                                    anchors.fill: parent

                                    ListModel {
                                        id: aspectRatioModel

                                        ListElement {
                                            ratio: "16:9"
                                        }
                                        ListElement {
                                            ratio: "4:3"
                                        }
                                        ListElement {
                                            ratio: "32:27"
                                        }
                                        ListElement {
                                            ratio: "1:1"
                                        }

                                        Component.onCompleted: {
                                            fromJSValue(sideBarSettings.aspectRatios);

                                            aspectRatioModel.dataChanged.connect(() => {
                                                sideBarSettings.aspectRatios = JSON.stringify(toJSValue());
                                            });
                                        }

                                        function fromJSValue(model) {
                                            var arr;

                                            try {
                                                if (!model.isEmpty()) {
                                                    arr = JSON.parse(model);
                                                }
                                            } catch(err) {
                                                Utils.log_error(qsTr("Error reading configuration!"));
                                            }

                                            if (arr instanceof Array) {
                                                for (var i = 0; i < arr.length; ++i) {
                                                    aspectRatioModel.set(i, arr[i]);
                                                }
                                            }
                                        }

                                        function toJSValue() {
                                            var arr = [];
                                            for (var i = 0; i < aspectRatioModel.count; ++i) {
                                                arr[i] = aspectRatioModel.get(i)
                                            }
                                            return arr;
                                        }
                                    }

                                    Repeater {
                                        model: aspectRatioModel
                                        delegate: Item {
                                            id: aspectRatioItem

                                            implicitWidth: aspectRatioTextField.implicitWidth
                                            implicitHeight: aspectRatioTextField.implicitHeight

                                            Layout.fillWidth: true

                                            Keys.onEscapePressed: {
                                                event.accepted = aspectRatioTextField.visible;
                                                aspectRatioTextField.cancel();
                                            }
                                            Keys.onPressed: {
                                                if (event.key === Qt.Key_F2 && rootWindowSettings.editMode) {
                                                    aspectRatioTextField.edit();
                                                }
                                            }

                                            Button {
                                                text: ratio
                                                enabled: rootWindowSettings.editMode
                                                opacity: enabled ? 1.0 : 0.5
                                                highlighted: {
                                                    Utils.currentModel().aspectRatio === str2ratio(ratio);
                                                }
                                                anchors.fill: parent

                                                onClicked: {
                                                    var r = str2ratio(ratio);
                                                    if (r) {
                                                        Utils.currentModel().aspectRatio = r;
                                                        setRootWindowRatio(r);
                                                    }
                                                }
                                                onPressAndHold: {
                                                    if (rootWindowSettings.editMode) {
                                                        aspectRatioTextField.edit();
                                                    }
                                                }

                                                ToolTip.delay: Compact.toolTipDelay
                                                ToolTip.timeout: Compact.toolTipTimeout
                                                ToolTip.visible: hovered
                                                ToolTip.text: rootWindowSettings.editMode ? qsTr("Press and hold to enter edit mode") : qsTr("Enable edit mode in Settings to modify")
                                            }

                                            TextField {
                                                id: aspectRatioTextField

                                                visible: false
                                                anchors.fill: parent
                                                horizontalAlignment: TextInput.AlignHCenter
                                                selectByMouse: true

                                                onEditingFinished: {
                                                    visible = false;
                                                    if(str2ratio(text)) {
                                                        ratio = text;
                                                    }
                                                }

                                                function edit() {
                                                    text = ratio;
                                                    visible = true;
                                                    forceActiveFocus();
                                                }

                                                function cancel() {
                                                    text = ratio;
                                                    visible = false;
                                                }
                                            }

                                            function str2ratio(str) {
                                                // Support 1-2 digit numbers for width and height (e.g., "32:27", "4:3", "16:9")
                                                var regexp = /^(\d{1,2}):(\d{1,2})$/;
                                                var match = str.match(regexp);
                                                if (match) {
                                                    var w = parseInt(match[1]);
                                                    var h = parseInt(match[2]);
                                                    if (w > 0 && h > 0) {
                                                        return Qt.size(w, h);
                                                    }
                                                }
                                                return null;
                                            }
                                        }
                                    }

                                }
                            }

                            GroupBox {
                                title: qsTr("Other")
                                palette.windowText: "white"

                                Layout.fillWidth: true

                                RowLayout {
                                    anchors.fill: parent

                                    Button {
                                        text: qsTr("Merging cells")
                                        enabled: rootWindowSettings.editMode && Utils.currentLayout().mergeCells(true)
                                        opacity: rootWindowSettings.editMode ? 1.0 : 0.5

                                        Layout.fillWidth: true

                                        onClicked: Utils.currentLayout().mergeCells()
                                    }
                                }
                            }
                        }
                    }
                    SideBarItem {
                        objectName: "viewport"
                        icon: "qrc:/images/menu-viewport.svg"
                        title: qsTr("Viewport%1").arg(currentViewportIndex >= 0 ? qsTr(" #%1").arg(currentViewportIndex + 1) : "")
                        locked: rootWindowSettings.lockViewportPanel

                        Layout.fillWidth: true

                        Frame {
                            id: viewportFrame

                            hoverEnabled: true
                            anchors.fill: parent

                            ToolTip {
                                visible: !viewportLayout.enabled && viewportFrame.hovered
                                text: qsTr("Select viewport!")
                                anchors.centerIn: parent
                            }

                            ColumnLayout {
                                id: viewportLayout

                                // Enabled only when any of the viewports are active.
                                enabled: rootSideBar.currentViewportIndex >= 0
                                anchors.fill: parent

                                TextField {
                                    id: urlTextField
                                    text: viewportLayout.enabled ? Utils.currentModel().get(currentViewportIndex).url : ""
                                    placeholderText: qsTr("Url")
                                    selectByMouse: true
                                    enabled: rootWindowSettings.editMode
                                    opacity: enabled ? 1.0 : 0.5

                                    Layout.fillWidth: true

                                    onEditingFinished: Utils.currentModel().get(currentViewportIndex).url = text
                                }

                                Button {
                                    text: qsTr("Mute")
                                    // Mute button is always accessible (not protected by edit mode)
                                    enabled: currentViewportIndex >= 0 ? Utils.currentLayout().get(currentViewportIndex).hasAudio : false
                                    highlighted: !(currentViewportIndex >= 0 && Utils.currentModel().get(currentViewportIndex).volume > 0 || viewportSettings.unmuteWhenFullScreen && Utils.currentLayout().fullScreenIndex >= 0)

                                    Layout.fillWidth: true

                                    onClicked: {
                                        if (Utils.currentModel().get(currentViewportIndex).volume > 0) {
                                            Utils.currentModel().get(currentViewportIndex).volume = 0;
                                        } else {
                                            Utils.currentModel().get(currentViewportIndex).volume = 1;
                                        }
                                    }
                                }


                                ColumnLayout {
                                    Layout.fillWidth: true
                                    enabled: rootWindowSettings.editMode
                                    opacity: enabled ? 1.0 : 0.5

                                    Text {
                                        text: qsTr("FFmpeg options")
                                        color: "white"
                                        font.pointSize: rootWindow.font.pointSize * 1.05
                                    }

                                    TextField {
                                        id: ffmpegOptionsTextField
                                        text: viewportLayout.enabled ? getOptionsString(Utils.currentModel().get(currentViewportIndex).avFormatOptions) : ""
                                        selectByMouse: true

                                        Layout.fillWidth: true

                                        onEditingFinished: {
                                            var options = Utils.parseOptions(text);
                                            var defaultAVFormatOptions = layoutsCollectionSettings.toJSValue("defaultAVFormatOptions");

                                            if (Object.keys(options).length == Object.keys(defaultAVFormatOptions).length) {
                                                for (var key in options) {
                                                    if (defaultAVFormatOptions[key] === undefined || String(defaultAVFormatOptions[key]) !== String(options[key])) {
                                                        Utils.currentModel().get(currentViewportIndex).avFormatOptions = options;
                                                        return;
                                                    }
                                                }

                                                Utils.currentModel().get(currentViewportIndex).avFormatOptions = {};
                                            } else {
                                                Utils.currentModel().get(currentViewportIndex).avFormatOptions = options;
                                            }
                                        }

                                        function getOptionsString(options) {
                                            Object.assignDefault(options, layoutsCollectionSettings.toJSValue("defaultAVFormatOptions"));
                                            return Utils.stringifyOptions(options);
                                        }

                                    }
                                }
                            }
                        }
                    }
                    SideBarItem {
                        objectName: "presets"
                        icon: "qrc:/images/menu-presets.svg"
                        title: qsTr("Views")

                        Layout.fillWidth: true

                        Frame {
                            anchors.fill: parent

                            GridLayout {
                                columns: 4
                                anchors.fill: parent

                                Repeater {
                                    model: layoutsCollectionModel.count
                                    delegate: Button {
                                        text: deleteMode ? "➖" : index + 1
                                        highlighted: stackLayout.currentIndex === index

                                        property bool deleteMode: false

                                        Keys.onEscapePressed: {
                                            event.accepted = deleteMode;
                                            deleteMode = false;
                                        }
                                        Keys.onDeletePressed: {
                                            if (rootWindowSettings.editMode) {
                                                deleteMode = true;
                                            }
                                        }

                                        Layout.fillWidth: true

                                        onClicked: {
                                            if (deleteMode) {
                                                presetDeleteDialog.index = index;
                                                presetDeleteDialog.open();
                                            } else {
                                                stackLayout.currentIndex = index;
                                            }
                                        }
                                        onPressAndHold: {
                                            if (rootWindowSettings.editMode && layoutsCollectionModel.count > 1) {
                                                deleteMode = !deleteMode;
                                            }
                                        }

                                        ToolTip.delay: Compact.toolTipDelay
                                        ToolTip.timeout: Compact.toolTipTimeout
                                        ToolTip.visible: hovered
                                        ToolTip.text: deleteMode ? qsTr("Press and hold to exit delete mode") : 
                                                      (rootWindowSettings.editMode ? qsTr("Press and hold to enter delete mode") : "")
                                    }
                                }

                                Button {
                                    id: addButton

                                    text: "➕"
                                    enabled: rootWindowSettings.editMode
                                    opacity: enabled ? 1.0 : 0.5

                                    Layout.fillWidth: true

                                    onClicked: layoutsCollectionModel.append().size = Qt.size(3, 3)
                                }

                                Button {
                                    text: qsTr("Full Screen")
                                    highlighted: Context.config.fullScreen

                                    Layout.columnSpan: 4
                                    Layout.fillWidth: true

                                    onClicked: Context.config.fullScreen = !Context.config.fullScreen
                                }
                            }
                        }

                        MessageDialog {
                            id: presetDeleteDialog

                            title: qsTr("Are you sure?")
                            icon: StandardIcon.Question
                            text: qsTr("Are you sure you want to delete preset #%1?").arg(index + 1)
                            informativeText: qsTr("It's an irreversible procedure. Be careful!")
                            standardButtons: MessageDialog.Yes | MessageDialog.No

                            property int index: -1

                            onYes: layoutsCollectionModel.remove(index)
                        }
                    }
                    SideBarItem {
                        icon: "qrc:/images/menu-settings.svg"
                        title: qsTr("Settings")

                        Layout.fillWidth: true

                        onClicked: settingsDialog.open()
                    }

                    // Flexible spacer - fills remaining space, pushes logo to bottom
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                    }

                    // Company logo - stays near footer, pushed down when panels expand
                    Item {
                        id: logoContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: rootSideBar.state === SideBar.Compact ? 40 : 180
                        Layout.bottomMargin: 5
                        
                        Image {
                            id: companyLogo
                            source: "qrc:/images/Astral-Node-Labs-Logo-Only.svg"
                            anchors.centerIn: parent
                            // Full width flush when expanded, mini when collapsed
                            width: rootSideBar.state === SideBar.Compact ? 40 : parent.width
                            height: rootSideBar.state === SideBar.Compact ? 40 : parent.height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            opacity: 0.5
                            
                            Behavior on width {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                            Behavior on height {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                        }
                        
                        Behavior on height {
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Row {
                    id: footerRow
                    width: parent.width
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: layout.verticalMargins
                    spacing: 0

                    SideBarItem {
                        id: footer

                        icon: "qrc:/images/menu-collapse.svg"
                        // Show collapse icon when sidebar is visible (Popup or Expanded), expand when Compact
                        mirrorIcon: rootSideBar.state === SideBar.Compact ^ mirrored
                        title: rootSideBar.state === SideBar.Compact ? qsTr("Expand") : qsTr("Collapse")
                        width: rootSideBar.state === SideBar.Compact ? parent.width : parent.width - pinButton.width

                        onClicked: {
                            if (rootSideBar.state === SideBar.Compact) {
                                // When expanding, use Expanded if pinned, Popup if unpinned
                                rootSideBar.state = rootWindowSettings.sidebarPinned ? SideBar.Expanded : SideBar.Popup
                            } else {
                                rootSideBar.state = SideBar.Compact
                            }
                        }
                    }

                    // Pin button - only visible when sidebar is expanded
                    Button {
                        id: pinButton
                        width: 40
                        height: footer.height
                        visible: rootSideBar.state !== SideBar.Compact
                        highlighted: !rootWindowSettings.sidebarPinned

                        Image {
                            id: pinIcon
                            source: "qrc:/images/menu-pin.svg"
                            width: 24
                            height: 24
                            anchors.centerIn: parent
                            fillMode: Image.PreserveAspectFit
                        }

                        // Color overlay for the pin icon
                        ColorOverlay {
                            anchors.fill: pinIcon
                            source: pinIcon
                            color: rootWindowSettings.sidebarPinned ? "white" : "#cccccc"
                        }

                        onClicked: {
                            rootWindowSettings.sidebarPinned = !rootWindowSettings.sidebarPinned
                            // If we just pinned and we're in Popup state, switch to Expanded
                            if (rootWindowSettings.sidebarPinned && rootSideBar.state === SideBar.Popup) {
                                rootSideBar.state = SideBar.Expanded
                            }
                            // If we just unpinned and we're in Expanded state, switch to Popup
                            else if (!rootWindowSettings.sidebarPinned && rootSideBar.state === SideBar.Expanded) {
                                rootSideBar.state = SideBar.Popup
                            }
                        }

                        ToolTip.delay: Compact.toolTipDelay
                        ToolTip.timeout: Compact.toolTipTimeout
                        ToolTip.visible: hovered
                        ToolTip.text: rootWindowSettings.sidebarPinned ? qsTr("Unpin sidebar (floating mode)") : qsTr("Pin sidebar (seated mode)")
                    }
                }
            }
        }
    }

    function setRootWindowRatio(ratio) {
        var horzRatio = Utils.currentModel().size.width * ratio.width;
        var vertRatio = Utils.currentModel().size.height * ratio.height;
        var pixels = Math.round((rootWindow.width - rootSideBar.width) / horzRatio);

        if (!Context.config.fullScreen) {
            rootWindow.width = horzRatio * pixels + rootSideBar.width;
            rootWindow.height = vertRatio * pixels;
        }
    }
}
