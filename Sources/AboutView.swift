import SwiftUI

/// Custom About window — tells the story behind the name.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 84, height: 84)
                }
                Text("Kitib")
                    .font(.system(size: 26, weight: .bold))
                Text("كاتب")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Version \(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 28)
            .padding(.bottom, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("The name")
                        .font(.headline)
                    Text("""
                    Kitib takes its name from the Arabic كاتب (kātib) — “writer,” or more literally, \
                    “one who writes.” The word comes from the three-letter root ك-ت-ب (k-t-b), \
                    “to write,” one of the most productive roots in the language: from it come \
                    kitāb (book), maktab (desk, office), maktaba (library), and kitāba (writing itself). \
                    A whole world of words, all growing from the simple act of putting pen to paper.
                    """)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Text("""
                    Historically, the kātib was more than a scribe — a trusted writer-craftsman whose \
                    clear prose kept courts, libraries, and ideas moving. That spirit is what this app \
                    is built around: no clutter, no distractions, just you, the page, and the work of \
                    writing. Everything else — preview, stats, export — stays out of the way until \
                    you ask for it.
                    """)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }

            Divider()

            HStack {
                Text("© 2026 Sean")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 420, height: 480)
    }
}
