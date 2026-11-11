// SPDX-License-Identifier: MIT
// Full preferences: one tab per area, every setting editable with live effect.

import AppKit
import SwiftUI
import ToolboxCore

struct PreferencesView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var snippetStore: SnippetStore
    var loginItems: LoginItemService
    var restartFeature: (FeatureID) -> Void

    @State private var launchAtLogin = false

    var body: some View {
        TabView {
            GeneralPane(store: store, loginItems: loginItems, launchAtLogin: $launchAtLogin)
                .tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            BreaksPane(store: store)
                .tabItem { Label("Breaks", systemImage: "cup.and.saucer") }.tag(1)
            KeepAwakePane(store: store, restart: { restartFeature(.keepAwake) })
                .tabItem { Label("Keep Awake", systemImage: "bolt") }.tag(2)
            AutoClosePane(store: store)
                .tabItem { Label("Auto-close", systemImage: "curlybraces") }.tag(3)
            SnippetsPane(store: store, snippetStore: snippetStore)
                .tabItem { Label("Snippets", systemImage: "text.quote") }.tag(4)
            ColorPane(store: store)
                .tabItem { Label("Color", systemImage: "eyedropper") }.tag(5)
        }
        .padding(16)
        .frame(width: 560, height: 460)
        .onAppear { launchAtLogin = loginItems.isEnabled }
    }
}

// MARK: - Small building blocks

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

/// Number stepper bound to an Int setting.
private struct IntSetting: View {
    let title: String
    let range: ClosedRange<Int>
    let step: Int
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper("\(value)", value: $value, in: range, step: step)
                .frame(minWidth: 140, alignment: .trailing)
        }
    }
}

private struct SettingToggle: View {
    let title: String
    let help: String
    @Binding var value: Bool
    var onChange: (() -> Void)?

    var body: some View {
        Toggle(isOn: Binding(get: { value }, set: { newValue in
            value = newValue
            onChange?()
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(help).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - App filter editor (shared by the input features)

struct AppFilterEditor: View {
    @Binding var filter: AppFilter
    @State private var newID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: $filter.mode) {
                Text("Block listed apps").tag(AppFilter.Mode.denylist)
                Text("Allow only listed apps").tag(AppFilter.Mode.allowlist)
            }
            .pickerStyle(.segmented)
            List {
                ForEach(filter.bundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).font(.caption).textSelection(.enabled)
                        Spacer()
                        Button {
                            filter.bundleIDs.removeAll { $0 == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 90)
            HStack {
                TextField("Bundle ID (suffix .* matches a prefix)", text: $newID)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addID)
                Button("Add", action: addID).disabled(newID.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Add Application…", action: pickApplication)
            }
        }
    }

    private func addID() {
        let id = newID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !filter.bundleIDs.contains(id) else { return }
        filter.bundleIDs.append(id)
        filter.bundleIDs.sort()
        newID = ""
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let id = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        guard !filter.bundleIDs.contains(id) else { return }
        filter.bundleIDs.append(id)
        filter.bundleIDs.sort()
    }
}

// MARK: - Panes

private struct GeneralPane: View {
    @ObservedObject var store: SettingsStore
    var loginItems: LoginItemService
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { value in
                    try? loginItems.setEnabled(value)
                    launchAtLogin = loginItems.isEnabled
                }
            InfoRow(title: "Version", value: "\(HelpInfo.version) (\(HelpInfo.build))")
            InfoRow(title: "Architecture", value: HelpInfo.architecture)
            Spacer()
        }
    }
}

private struct BreaksPane: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IntSetting(title: "Work minutes", range: 5...180, step: 5, value: Binding(
                get: { store.settings.breaks.workMinutes },
                set: { newValue in store.update { settings in settings.breaks.workMinutes = newValue } }
            ))
            IntSetting(title: "Break minutes", range: 1...60, step: 1, value: Binding(
                get: { store.settings.breaks.breakMinutes },
                set: { newValue in store.update { settings in settings.breaks.breakMinutes = newValue } }
            ))
            IntSetting(title: "Reset after idle (min)", range: 1...60, step: 1, value: Binding(
                get: { store.settings.breaks.idleResetMinutes },
                set: { newValue in store.update { settings in settings.breaks.idleResetMinutes = newValue } }
            ))
            SettingToggle(title: "Overlay window",
                          help: "Full-screen translucent countdown on every display.",
                          value: Binding(
                              get: { store.settings.breaks.overlay },
                              set: { newValue in store.update { settings in settings.breaks.overlay = newValue } }
                          ))
            SettingToggle(title: "Sound",
                          help: "Play the notification sound.",
                          value: Binding(
                              get: { store.settings.breaks.sound },
                              set: { newValue in store.update { settings in settings.breaks.sound = newValue } }
                          ))
            Spacer()
        }
    }
}

private struct KeepAwakePane: View {
    @ObservedObject var store: SettingsStore
    var restart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingToggle(title: "Allow display sleep",
                          help: "Prevents system sleep but lets the display turn off.",
                          value: Binding(
                              get: { store.settings.keepAwake.allowDisplaySleep },
                              set: { newValue in
                                  store.update { settings in settings.keepAwake.allowDisplaySleep = newValue }
                                  restart()
                              }
                          ))
            Text("Default duration").font(.headline)
            Picker("Default duration", selection: Binding(
                get: { store.settings.keepAwake.defaultDuration ?? -1 },
                set: { newValue in
                    store.update { settings in settings.keepAwake.defaultDuration = newValue < 0 ? nil : newValue }
                    restart()
                }
            )) {
                Text("Indefinite").tag(-1.0)
                Text("15 min").tag(900.0)
                Text("1 h").tag(3600.0)
                Text("2 h").tag(7200.0)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Spacer()
        }
    }
}

private struct AutoClosePane: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pairs").font(.headline)
            List {
                ForEach(store.settings.autoClose.pairs.indices, id: \.self) { index in
                    let pair = store.settings.autoClose.pairs[index]
                    Toggle(isOn: Binding(
                        get: { pair.enabled },
                        set: { newValue in store.update { settings in settings.autoClose.pairs[index].enabled = newValue } }
                    )) {
                        Text("\(pair.open) … \(pair.close)").font(.body.monospaced())
                    }
                }
            }
            .frame(minHeight: 150)
            SettingToggle(title: "Tab out",
                          help: "Tab jumps past the pending closer.",
                          value: Binding(
                              get: { store.settings.autoClose.tabOut },
                              set: { newValue in store.update { settings in settings.autoClose.tabOut = newValue } }
                          ))
            SettingToggle(title: "Overtype",
                          help: "Typing the closer moves past it instead of duplicating.",
                          value: Binding(
                              get: { store.settings.autoClose.overtype },
                              set: { newValue in store.update { settings in settings.autoClose.overtype = newValue } }
                          ))
            SettingToggle(title: "Pair backspace",
                          help: "Backspace right after pairing deletes both characters.",
                          value: Binding(
                              get: { store.settings.autoClose.deletePair },
                              set: { newValue in store.update { settings in settings.autoClose.deletePair = newValue } }
                          ))
            SettingToggle(title: "Smart quotes",
                          help: "No pairing for ' \" ` after letters or digits.",
                          value: Binding(
                              get: { store.settings.autoClose.smartQuotes },
                              set: { newValue in store.update { settings in settings.autoClose.smartQuotes = newValue } }
                          ))
            SettingToggle(title: "Require editable focus",
                          help: "Only pair when the focused element is a text field.",
                          value: Binding(
                              get: { store.settings.autoClose.requireEditableFocus },
                              set: { newValue in store.update { settings in settings.autoClose.requireEditableFocus = newValue } }
                          ))
            Text("Application filter").font(.headline)
            AppFilterEditor(filter: Binding(
                get: { store.settings.autoClose.filter },
                set: { newValue in store.update { settings in settings.autoClose.filter = newValue } }
            ))
        }
    }
}

private struct SnippetsPane: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var snippetStore: SnippetStore
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Snippets").font(.headline)
                Spacer()
                Button("Add") {
                    let snippet = Snippet(trigger: ";new", title: "New", body: "")
                    var all = snippetStore.snippets
                    all.append(snippet)
                    snippetStore.replaceAll(with: all)
                    selection = snippet.id
                }
                Button("Delete") {
                    guard let selection else { return }
                    snippetStore.replaceAll(with: snippetStore.snippets.filter { $0.id != selection })
                    self.selection = nil
                }
                .disabled(selection == nil)
                Button("Import…", action: importSnippets)
                Button("Export…", action: exportSnippets)
            }
            List(snippetStore.snippets, selection: $selection) { snippet in
                HStack {
                    Toggle(isOn: Binding(
                        get: { snippet.enabled },
                        set: { newValue in setEnabled(snippet.id, newValue) }
                    )) {
                        EmptyView()
                    }
                    .toggleStyle(.checkbox)
                    VStack(alignment: .leading) {
                        Text(snippet.trigger).font(.headline.monospaced())
                        Text(snippet.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(snippet.id)
            }
            .frame(minHeight: 120)
            if let selected = snippetStore.snippets.first(where: { $0.id == selection }) {
                TextField("Trigger", text: Binding(
                    get: { selected.trigger },
                    set: { newValue in setField(selected.id, trigger: newValue) }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Title", text: Binding(
                    get: { selected.title },
                    set: { newValue in setField(selected.id, title: newValue) }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Body (supports {clipboard}, {date}, {time}, {cursor})").font(.caption)
                TextEditor(text: Binding(
                    get: { selected.body },
                    set: { newValue in setField(selected.id, body: newValue) }
                ))
                .font(.body.monospaced())
                .frame(minHeight: 60)
                .border(Color.secondary.opacity(0.3))
            }
            SettingToggle(title: "Expand on delimiter",
                          help: "Space, Tab, Return or punctuation completes the trigger.",
                          value: Binding(
                              get: { store.settings.snippets.expandOnDelimiter },
                              set: { newValue in store.update { settings in settings.snippets.expandOnDelimiter = newValue } }
                          ))
            SettingToggle(title: "Expand immediately",
                          help: "Expand as soon as the trigger is typed, no delimiter needed.",
                          value: Binding(
                              get: { store.settings.snippets.expandImmediately },
                              set: { newValue in store.update { settings in settings.snippets.expandImmediately = newValue } }
                          ))
            HStack {
                Text("Date format")
                TextField("yyyy-MM-dd", text: Binding(
                    get: { store.settings.snippets.dateFormat },
                    set: { newValue in store.update { settings in settings.snippets.dateFormat = newValue } }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Time format")
                TextField("HH:mm", text: Binding(
                    get: { store.settings.snippets.timeFormat },
                    set: { newValue in store.update { settings in settings.snippets.timeFormat = newValue } }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func setEnabled(_ id: UUID, _ enabled: Bool) {
        snippetStore.replaceAll(with: snippetStore.snippets.map { snippet in
            var copy = snippet
            if copy.id == id { copy.enabled = enabled }
            return copy
        })
    }

    private func setField(_ id: UUID, trigger: String? = nil, title: String? = nil, body: String? = nil) {
        snippetStore.replaceAll(with: snippetStore.snippets.map { snippet in
            var copy = snippet
            guard copy.id == id else { return copy }
            if let trigger { copy.trigger = trigger }
            if let title { copy.title = title }
            if let body { copy.body = body }
            return copy
        })
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? snippetStore.importJSON(from: url)
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "snippets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? snippetStore.exportJSON(to: url)
    }
}

private struct ColorPane: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Format", selection: Binding(
                get: { store.settings.colorPicker.format },
                set: { newValue in store.update { settings in settings.colorPicker.format = newValue } }
            )) {
                Text("HEX").tag(ColorFormat.hex)
                Text("rgb()").tag(ColorFormat.rgb)
                Text("hsl()").tag(ColorFormat.hsl)
                Text("SwiftUI Color").tag(ColorFormat.swiftUI)
                Text("NSColor").tag(ColorFormat.nsColor)
            }
            SettingToggle(title: "Uppercase hex",
                          help: "#1E90FF instead of #1e90ff.",
                          value: Binding(
                              get: { store.settings.colorPicker.uppercase },
                              set: { newValue in store.update { settings in settings.colorPicker.uppercase = newValue } }
                          ))
            HStack {
                Text("Recent colors").font(.headline)
                Spacer()
                Button("Clear") {
                    store.update { settings in settings.colorPicker.recents = [] }
                }
                .disabled(store.settings.colorPicker.recents.isEmpty)
            }
            if store.settings.colorPicker.recents.isEmpty {
                Text("No recent colors yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.settings.colorPicker.recents, id: \.self) { value in
                    Text(value).font(.caption.monospaced())
                }
            }
            Spacer()
        }
    }
}
