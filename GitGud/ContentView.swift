//
//  ContentView.swift
//  GitGud
//
//  Created by Ben Dixon on 03/12/2024.
//

import SwiftUI
import Foundation

struct Commit: Identifiable, Hashable {
    let id: String  // commit hash
    let message: String
    let author: String
    let date: Date
}

struct ContentView: View {
    @State private var commits: [Commit] = []
    @State private var selectedCommit: Commit?
    @State private var errorMessage: String = ""
    
    @State private var sliderValue = 0.0
    @State private var isDragging = false // Track slider interaction

    var body: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                List(commits, id: \.id, selection: $selectedCommit) { commit in
                    VStack(alignment: .leading) {
                        Text(commit.message)
                            .font(.headline)
                        Text(commit.id)
                            .lineLimit(1)
                        HStack {
                            Text(commit.author)
                                .font(.subheadline)
                            Spacer()
                            Text("\(commit.date, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }.tag(commit)
                }
                .onChange(of: selectedCommit) { oldValue, newValue in
                    if let newValue, let index = commits.firstIndex(of: newValue) {
                        // Check out
                        checkoutCommit(commit: newValue, head: index == 0)
                        
                        withAnimation {
                            proxy.scrollTo(newValue.id)
                        }
                        if !isDragging, newValue != oldValue  {
                            sliderValue = Double(index)
                        }
                    }
                }
                .onAppear {
                    print("FETCHING")
                    fetchRecentCommits()
                }
                
                if !errorMessage.isEmpty {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
        } detail: {
            VStack {
                Slider(
                    value: Binding(
                        get: {
                            sliderValue
                        },
                        set: { newValue in
                            // Mark as dragging
                            isDragging = true
                            sliderValue = max(0, min(newValue, Double(commits.count - 1)))
                            
                            // Update `selectedCommit` only if it's different
                            let index = Int(sliderValue)
                            if index < commits.count {
                                let newCommit = commits[index]
                                if selectedCommit != newCommit {
                                    selectedCommit = newCommit
                                }
                            }
                        }
                    ),
                    in: 0...Double(max(0, commits.count - 1))
//                    step: 1
                )
                .gesture(DragGesture().onEnded { _ in
                    isDragging = false // Reset dragging flag when interaction ends
                })
                
                Spacer()
                
                Text("Total Commits: \(commits.count)")
                Text("Slider Value: \(sliderValue)")
                Text("Selected Commit: \(selectedCommit?.id ?? "none")")
            }
            .padding()
        }
        .navigationTitle(selectedCommit != nil ? "Commit: \(selectedCommit!.message)" : "Commits")
    }
    
    func fetchRecentCommits() {
        let task = Process()
        task.launchPath = "/usr/bin/git"
        task.arguments = [
            "--no-pager",
            "-C", "/Users/malted/HC/high-seas",
            "log",
//            "-n", "10",
            "--pretty=format:%H%n%an%n%ad%n%s"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
                parseCommits(output: output)
            }
            
            task.waitUntilExit()
        } catch {
            errorMessage = "Failed to execute git command: \(error.localizedDescription)"
        }
    }
    
    func parseCommits(output: String) {
        let lines = output.components(separatedBy: .newlines)
        var parsedCommits: [Commit] = []
        
        // Date formatter for git's default date format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy Z"
        
        stride(from: 0, to: lines.count, by: 4).forEach { index in
            guard index + 3 < lines.count else { return }
            
            let hash = lines[index]
            let author = lines[index + 1]
            guard let date = dateFormatter.date(from: lines[index + 2]) else { return }
            let message = lines[index + 3]
            
            parsedCommits.append(Commit(
                id: hash,
                message: message,
                author: author,
                date: date
            ))
        }
        
        commits = parsedCommits
    }
    
    func checkoutCommit(commit: Commit, head: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/git"
        task.arguments = [
            "--no-pager",
            "-C", "/Users/malted/HC/high-seas",
            "checkout",
            head ? "main" : commit.id
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
//                print(output)
            }
            
            task.waitUntilExit()
        } catch {
            errorMessage = "Failed to execute git command: \(error.localizedDescription)"
        }
    }
}


#Preview {
    ContentView()
}
