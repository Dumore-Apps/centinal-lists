import ContentBlockerConverter
import Foundation

// blockgen — build-time tool. Reads an Adblock-Plus-syntax filter list and writes
// the Safari content-blocker JSON (via AdGuard's SafariConverterLib) to a file.
// Optional maxBytes keeps the output safely under the iOS content-blocker OOM
// ceiling (~6 MB; we budget well below). The shipped list is a derived artifact:
//   swift run blockgen FilterLists/easylist.txt ContentBlocker/blockerList.json 1800000

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: blockgen <input.txt> <output.json> [maxBytes]\n".utf8))
    exit(2)
}

let maxBytes = args.count >= 4 ? Int(args[3]) : nil

let text = try String(contentsOfFile: args[1], encoding: .utf8)
let rules = text
    .split(whereSeparator: \.isNewline)
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty && !$0.hasPrefix("!") && !$0.hasPrefix("[") }

let result = ContentBlockerConverter().convertArray(rules: rules, maxJsonSizeBytes: maxBytes)
try Data(result.safariRulesJSON.utf8).write(to: URL(fileURLWithPath: args[2]))

FileHandle.standardError.write(Data(
    "blockgen: \(result.safariRulesCount) Safari rules, \(result.errorsCount) errors, \(result.safariRulesJSON.utf8.count) bytes → \(args[2])\n".utf8))
