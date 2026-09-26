import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import CCTV_Viewer.Utils 1.0

Dialog {
    title: qsTr("Settings")
    modality: Qt.ApplicationModal
    standardButtons: StandardButton.Ok | StandardButton.Cancel

    onVisibleChanged: {
        if (visible) {
            loadSettings();
        }
    }
    onAccepted: saveSettings()

    ColumnLayout {
        anchors.fill: parent

        GroupBox {
            title: qsTr("General")

            Layout.fillWidth: true

            ColumnLayout {

                width: parent.width

                CheckBox {
                    id: singleApplicationCheckBox

                    text: qsTr("Allow running multiple application instances")
                }

                CheckBox {
                    id: sidebarAutoCollapseCheckBox

                    text: qsTr("Automatically collapse sidebar") 
                }

                CheckBox {
                    id: editModeCheckBox

                    text: qsTr("Enable edit mode (unlock layout settings in sidebar)")
                }

                CheckBox {
                    id: lockToolsPanelCheckBox

                    text: qsTr("Lock Tools panel (keep collapsed)")
                }

                CheckBox {
                    id: lockViewportPanelCheckBox

                    text: qsTr("Lock Viewport panel (keep collapsed)")
                }
            }
        }

        GroupBox {
            title: qsTr("View")

            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width

                CheckBox {
                    id: presetIndicatorCheckBox

                    text: qsTr("Show preset indicator")
                }

                CheckBox {
                    id: hideCursorWhenFullScreenCheckBox

                    text: qsTr("Hide cursor in full screen mode")
                }
            }
        }

        GroupBox {
            title: qsTr("Viewport")

            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width

                CheckBox {
                    id: unmuteWhenFullScreenCheckBox

                    text: qsTr("Unmute when the viewport is in full screen mode")
                }

                CheckBox {
                    id: persistentStreamsCheckBox

                    text: qsTr("Keep streams running between preset switches")
                }

                Label {
                    text: qsTr("Default FFmpeg options")
                }

                TextField {
                    id: defaultAVFormatOptions

                    selectByMouse: true

                    Layout.fillWidth: true
                }
            }
        }

        GroupBox {
            title: qsTr("Presets")

            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width

                RowLayout  {
                    width: parent.width

                    CheckBox {
                        id: carouselRunningCheckBox

                        text: qsTr("Run presets carousel with interval (sec.):")

                        Layout.fillWidth: true
                    }

                    SpinBox {
                        id: carouselIntervalSpinBox

                        property int valueFactor: 1000

                        enabled: carouselRunningCheckBox.checked

                        stepSize: 100
                        from: stepSize
                        to: 300 * stepSize
                        editable: true

                        validator: DoubleValidator {
                            decimals: 2
                            bottom: Math.min(carouselIntervalSpinBox.from, carouselIntervalSpinBox.to)
                            top:  Math.max(carouselIntervalSpinBox.from, carouselIntervalSpinBox.to)
                        }
                        textFromValue: function(value, locale) {
                            return Number(value / valueFactor).toLocaleString(locale, 'f', validator.decimals)
                        }
                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * valueFactor
                        }
                    }
                }
            }
        }
    }

    function loadSettings() {
        singleApplicationCheckBox.checked = !generalSettings.singleApplication;
        
        sidebarAutoCollapseCheckBox.checked = rootWindowSettings.sidebarAutoCollapse;
        editModeCheckBox.checked = rootWindowSettings.editMode;
        lockToolsPanelCheckBox.checked = rootWindowSettings.lockToolsPanel;
        lockViewportPanelCheckBox.checked = rootWindowSettings.lockViewportPanel;
        
        presetIndicatorCheckBox.checked = layoutsCollectionSettings.presetIndicator;

        hideCursorWhenFullScreenCheckBox.checked = viewSettings.hideCursorWhenFullScreen;

        unmuteWhenFullScreenCheckBox.checked = viewportSettings.unmuteWhenFullScreen;
        persistentStreamsCheckBox.checked = viewportSettings.persistentStreams;

        carouselRunningCheckBox.checked = presetsSettings.carouselRunning;
        carouselIntervalSpinBox.value = presetsSettings.carouselInterval;

        defaultAVFormatOptions.text = "";
        var options = layoutsCollectionSettings.toJSValue("defaultAVFormatOptions");
        for (var key in options) {
            if (typeof options[key] === "string" || typeof options[key] === "number") {
                defaultAVFormatOptions.text += "-%1 %2 ".arg(key).arg(options[key]);
            }
        }
        defaultAVFormatOptions.text = defaultAVFormatOptions.text.trim();
    }

    function saveSettings() {
        generalSettings.singleApplication = !singleApplicationCheckBox.checked;
        
        rootWindowSettings.sidebarAutoCollapse = sidebarAutoCollapseCheckBox.checked;
        rootWindowSettings.editMode = editModeCheckBox.checked;
        rootWindowSettings.lockToolsPanel = lockToolsPanelCheckBox.checked;
        rootWindowSettings.lockViewportPanel = lockViewportPanelCheckBox.checked;
        
        layoutsCollectionSettings.presetIndicator = presetIndicatorCheckBox.checked;

        viewSettings.hideCursorWhenFullScreen = hideCursorWhenFullScreenCheckBox.checked;

        viewportSettings.unmuteWhenFullScreen = unmuteWhenFullScreenCheckBox.checked;
        viewportSettings.persistentStreams = persistentStreamsCheckBox.checked;

        presetsSettings.carouselRunning = carouselRunningCheckBox.checked;
        presetsSettings.carouselInterval = carouselIntervalSpinBox.value;

        layoutsCollectionSettings.defaultAVFormatOptions = JSON.stringify(Utils.parseOptions(defaultAVFormatOptions.text));
    }
}
