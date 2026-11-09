import SwiftUI
import SwiftData

// MARK: - Undo Delete Toast

/// Shows "Deleted X — Undo" for a few seconds after items are deleted.
private struct UndoDeleteToast: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Binding var mementos: [DeletedItemMemento]
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if !mementos.isEmpty {
                    HStack {
                        Text(mementos.count == 1
                             ? "Deleted \"\(mementos[0].name)\""
                             : "Deleted \(mementos.count) items")
                            .lineLimit(1)
                        Spacer()
                        Button("Undo") {
                            dismissTask?.cancel()
                            for memento in mementos {
                                ItemActions.restore(memento, in: modelContext)
                            }
                            mementos = []
                        }
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring, value: mementos.isEmpty)
            .onChange(of: mementos.count) { _, count in
                dismissTask?.cancel()
                guard count > 0 else { return }
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled { mementos = [] }
                }
            }
            .sensoryFeedback(.success, trigger: mementos.isEmpty) { wasEmpty, isEmpty in wasEmpty && !isEmpty }
    }
}

extension View {
    func undoDeleteToast(_ mementos: Binding<[DeletedItemMemento]>) -> some View {
        modifier(UndoDeleteToast(mementos: mementos))
    }
}

// MARK: - Thumbnail

struct ItemThumbnailView: View {
    let item: Item
    var size: CGFloat = 44

    var body: some View {
        let category = item.category ?? .other
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(Theme.surfaceMuted)
            if let data = item.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: category.icon)
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Share Sheet

struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Card styling

extension View {
    func cardBackground(tint: Color? = nil) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.map { $0.opacity(0.08) } ?? Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.map { $0.opacity(0.25) } ?? .clear, lineWidth: 1)
            )
    }
}

// MARK: - Alerts bound to optional messages

extension View {
    /// Presents an alert whenever `message` is non-nil and clears it on dismissal.
    func messageAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// MARK: - Keyboard

/// Ends editing in whichever text field is active, including ones not bound to a FocusState.
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
