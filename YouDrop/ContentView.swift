//
//  ContentView.swift
//  YouDrop
//
//  Created by Alex on 4/3/25.
//

import SwiftUI

enum Format: String, CaseIterable, Identifiable {
    case mp4 = "MP4 (відео)"
    case mp3 = "MP3 (аудіо)"
    var id: String { rawValue }
}

let videoQualityOptions = ["best", "best[height<=720]", "best[height<=480]", "worst"]

struct ContentView: View {
    @State private var urlString: String = ""
    @State private var isDownloading = false
    @State private var statusMessage = NSLocalizedString("input.prompt", comment: "")
    @State private var selectedFormat: Format = .mp4
    @State private var selectedQuality: String = videoQualityOptions[0]
    @State private var logOutput: String = ""
    @State private var showOpenButton: Bool = false
    @State private var lastDownloadedFile: String? = nil
    @State private var savedFileURL: URL? = nil
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("YouDrop")
                .font(.largeTitle)
                .bold()
            
            Text(statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            TextField("https://www.youtube.com/watch?v=...", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            //            Picker("Format", selection: $selectedFormat) {
            //                ForEach(Format.allCases) { format in
            //                    Text(format.rawValue).tag(format)
            //                }
            //            }
            //            .pickerStyle(SegmentedPickerStyle())
            //            .padding(.horizontal)
            
            if selectedFormat == .mp4 {
                Picker(LocalizedStringKey("label.video.quality"), selection: $selectedQuality) {
                    ForEach(videoQualityOptions, id: \ .self) { quality in
                        Text(quality).tag(quality)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                Button(LocalizedStringKey("button.paste.clipboard")) {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        urlString = clipboard
                    }
                }
                
                Button(LocalizedStringKey("button.download")) {
                    presentSavePanel()
                }.disabled(urlString.isEmpty || isDownloading)
            }
            
            if isDownloading {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
            }
            
            TextEditor(text: $logOutput)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 120)
                .border(Color.gray.opacity(0.5), width: 1)
            
            if let file = lastDownloadedFile {
                Text(String(format: NSLocalizedString("label.saved.as", comment: "saved as: %@"), file))
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if showOpenButton {
                Button(LocalizedStringKey("button.show.in.finder")) {
                    if let url = savedFileURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 640)
        .onDrop(of: [.url, .plainText], isTargeted: nil) { providers in
            if let item = providers.first {
                _ = item.loadObject(ofClass: String.self) { object, _ in
                    if let string = object {
                        DispatchQueue.main.async {
                            urlString = string
                        }
                    }
                }
            }
            return true
        }
    }
    
    func presentSavePanel() {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("panel.title", comment: "")
        panel.allowedFileTypes = [selectedFormat == .mp4 ? "mp4" : "mp3"]
        panel.nameFieldStringValue = "video.\(selectedFormat == .mp4 ? "mp4" : "mp3")"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                savedFileURL = url
                downloadVideo(to: url)
            }
        }
    }
    
    func downloadVideo(to destinationURL: URL) {
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = NSLocalizedString("status.downloading", comment: "")
        logOutput = ""
        showOpenButton = false
        lastDownloadedFile = nil
        
        guard let ytDlpPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) else {
            statusMessage = NSLocalizedString("error.ytdlp.notfound.status", comment: "")
            logOutput += "‼️ " + NSLocalizedString("error.ytdlp.notfound.log", comment: "") + "\n"
            isDownloading = false
            return
        }
        
        logOutput += "✅ " + String(format: NSLocalizedString("log.ytdlp.found", comment: ""), ytDlpPath) + "\n"
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputTemplate = tempDir.appendingPathComponent("%(title)s.%(ext)s").path
        var arguments = ["\(urlString)", "-o", outputTemplate, "--no-playlist"]
        
        switch selectedFormat {
        case .mp4:
            arguments += ["-f", selectedQuality, "--merge-output-format", "mp4"]
        case .mp3:
            arguments += ["-x", "--audio-format", "mp3"]
        }
        
        logOutput += "👉 " + String(format: NSLocalizedString("log.command", comment: ""), "\(ytDlpPath) \(arguments.joined(separator: " "))") + "\n"
        
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.executableURL = URL(fileURLWithPath: ytDlpPath)
        task.arguments = arguments
        
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    print("YT-DLP RAW OUTPUT:\n", output)
                    let cleanedOutput = output.replacingOccurrences(of: "(?m)^\\[PYI-.*\n?", with: "", options: .regularExpression)
                    logOutput += cleanedOutput
                    
                    if let percentRange = cleanedOutput.range(of: "\\d+(\\.\\d+)?%", options: .regularExpression) {
                        let percentString = cleanedOutput[percentRange].replacingOccurrences(of: "%", with: "")
                        if let value = Double(percentString) {
                            downloadProgress = value / 100.0
                        }
                    }
                }
            }
        }
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                isDownloading = false
                handle.readabilityHandler = nil
                
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
                    if let matchName = contents.filter({ $0.hasSuffix(".mp4") || $0.hasSuffix(".mp3") }).sorted(by: {
                        let a = tempDir.appendingPathComponent($0)
                        let b = tempDir.appendingPathComponent($1)
                        let aTime = (try? FileManager.default.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? Date.distantPast
                        let bTime = (try? FileManager.default.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? Date.distantPast
                        return aTime > bTime
                    }).first {
                        let tempFileURL = tempDir.appendingPathComponent(matchName)
                        lastDownloadedFile = matchName
                        
                        if FileManager.default.fileExists(atPath: tempFileURL.path) {
                            try FileManager.default.moveItem(at: tempFileURL, to: destinationURL)
                            savedFileURL = destinationURL
                            statusMessage = String(format: NSLocalizedString("status.saved", comment: ""), destinationURL.lastPathComponent)
                            showOpenButton = true
                        } else {
                            statusMessage = NSLocalizedString("error.tempfile.notfound.status", comment: "")
                            logOutput += "‼️ " + String(format: NSLocalizedString("error.tempfile.notfound.log", comment: ""), tempFileURL.path) + "\n"
                        }
                    } else {
                        statusMessage = NSLocalizedString("error.file.missing.status", comment: "")
                        logOutput += "‼️ " + NSLocalizedString("error.file.missing.log", comment: "") + "\n"
                    }
                } catch {
                    statusMessage = NSLocalizedString("error.tempdir.failed", comment: "")
                    logOutput += "‼️ \(error.localizedDescription)\n"
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            DispatchQueue.main.async {
                statusMessage = String(format: NSLocalizedString("error.run.failed.status", comment: ""), error.localizedDescription)
                logOutput += "‼️ \(error.localizedDescription)\n"
                isDownloading = false
            }
        }
    }
}
#Preview {
    ContentView()
}
