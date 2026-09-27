import QtQuick
import qs.Commons
import "Model.js" as Model

// The calendars page: what Omagenda is showing you, and the one button that
// connects Google. There is deliberately nothing to fill in — the OAuth client
// ships with the plugin, so consent in a browser is the whole setup.
//
// Four states, and only one of them is ever on screen: no client in this build,
// not connected, waiting on the browser, connected. Each replaces the others
// rather than greying out, so the page never shows a control that cannot work.
Column {
  id: root

  property var chrome: null

  // [{ id, name, role, added, color, writable, primary }] — built by Panel.qml
  // from the service's calendar list and its sources.
  property var rows: []
  property string localColor: "none"

  property bool available: false
  property bool connected: false
  property bool connecting: false
  property bool syncing: false
  property string clientOrigin: ""
  property string error: ""
  property double lastSynced: 0
  property string todayISO: ""
  property bool use24Hour: true

  signal connectRequested()
  signal cancelRequested()
  signal disconnectRequested()
  signal syncRequested()
  signal toggled(string calendarId)
  signal closed()

  spacing: Style.space(20)

  // --- heading ------------------------------------------------------------------
  Text {
    text: "CALENDARS"
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
  }

  Rectangle {
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.rule : "transparent"
  }

  // --- the calendars ------------------------------------------------------------
  Column {
    width: parent.width
    spacing: 0

    // The local store is a calendar too, and saying so is what makes the Google
    // ones legible as additions rather than as the only thing here.
    CalendarRow {
      width: parent.width
      chrome: root.chrome
      name: "Local"
      note: "ALWAYS ON"
      color: root.localColor
      added: true
      fixed: true
    }

    Repeater {
      model: root.rows

      delegate: CalendarRow {
        required property var modelData
        width: parent.width
        chrome: root.chrome
        name: modelData.name
        note: modelData.writable ? (modelData.primary ? "PRIMARY" : "") : "READ-ONLY"
        color: modelData.color
        added: modelData.added
        onToggled: root.toggled(modelData.id)
      }
    }
  }

  // --- what to say about Google -------------------------------------------------
  // One paragraph, whichever state we are in, in place of a settings form.
  Text {
    width: parent.width
    visible: text !== ""
    text: {
      if (!root.available)
        return "This build has no Google client, so there is nothing to connect. "
             + "See docs/google-setup.md — either build one in, or put your own in "
             + "~/.config/omagenda/google-client.json."
      if (root.connecting)
        return "Waiting for your browser. Allow Omagenda to read and write your "
             + "events, then come back. If Google says it has not verified "
             + "Omagenda, choose Advanced → Go to Omagenda."
      if (!root.connected)
        return "Omagenda will open your browser once. It asks to read and write "
             + "events, and to see which calendars you have — not to create or "
             + "delete calendars. Nothing to copy, no keys to find."
      if (root.rows.length === 0)
        return "Connected, but Google returned no calendars. Press SYNC NOW to ask again."
      return ""
    }
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
    lineHeight: 1.35
  }

  // --- status -------------------------------------------------------------------
  Text {
    width: parent.width
    visible: text !== ""
    text: {
      if (root.error !== "") return root.error
      if (!root.connected) return ""
      if (root.syncing) return "Syncing…"
      var origin = root.clientOrigin === "user"
        ? "your own Google project"
        : (root.clientOrigin === "env" ? "a client from the environment" : "")
      var stamp = Model.syncedLabel(root.lastSynced, root.todayISO, root.use24Hour)
      var line = stamp === "" ? "Not synced yet" : "Last synced " + stamp
      return origin === "" ? line : line + "  ·  " + origin
    }
    color: root.chrome
      ? (root.error !== "" ? root.chrome.urgent : root.chrome.dimmer)
      : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    wrapMode: Text.WordWrap
  }

  // --- actions ------------------------------------------------------------------
  Row {
    spacing: Style.space(10)

    OutlineButton {
      chrome: root.chrome
      visible: root.available && !root.connected && !root.connecting
      glyph: "\u{F02AD}"                         // google
      label: "SYNC WITH GOOGLE CALENDAR"
      onClicked: root.connectRequested()
    }

    OutlineButton {
      chrome: root.chrome
      visible: root.connecting
      label: "CANCEL"
      onClicked: root.cancelRequested()
    }

    OutlineButton {
      chrome: root.chrome
      visible: root.connected && !root.connecting
      glyph: "\u{F04E6}"                         // sync
      label: "SYNC NOW"
      enabled: !root.syncing
      onClicked: root.syncRequested()
    }

    OutlineButton {
      chrome: root.chrome
      visible: root.connected && !root.connecting
      label: "DISCONNECT"
      danger: true
      onClicked: root.disconnectRequested()
    }

    OutlineButton {
      chrome: root.chrome
      label: "BACK"
      onClicked: root.closed()
    }
  }
}
