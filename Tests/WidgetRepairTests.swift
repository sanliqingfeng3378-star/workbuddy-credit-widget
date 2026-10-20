import Foundation

@main
struct WidgetRepairTests {
    static func main() {
        let executable = "/Applications/WorkBuddy Credits.app/Contents/PlugIns/WorkBuddyCreditsWidget.appex/Contents/MacOS/WorkBuddyCreditsWidget"
        let processes = """
          123 \(executable)
          456 /Applications/Other.app/Contents/MacOS/WorkBuddyCreditsWidget
          789 \(executable).backup
          890 /tmp/WorkBuddy Credits.app/Contents/PlugIns/WorkBuddyCreditsWidget.appex/Contents/MacOS/WorkBuddyCreditsWidget
          1 \(executable)
          -42 \(executable)
          bad \(executable)
          124 \(executable)
        """
        precondition(WidgetRepairWorker.matchingPIDs(processes, executable: executable) == [123, 124])
        precondition(WidgetRepairWorker.matchingPIDs("", executable: executable).isEmpty)
        do {
            try WidgetRepairWorker.run(appURL: URL(fileURLWithPath: "/nonexistent/workbuddy-test.app"))
            preconditionFailure("A missing extension must stop the repair before running commands.")
        } catch WidgetRepairError.missingExtension {
            // Expected: no registration or process termination.
        } catch {
            preconditionFailure("Unexpected error: \(error)")
        }
        print("PASS: repair targets exact extension paths, excludes system PIDs, and rejects missing bundles")
    }
}
