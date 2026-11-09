import SwiftUI

/// Full-screen, swipeable photo viewer with pinch/double-tap zoom.
struct PhotoViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let images: [UIImage]
    @State var selection: Int

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImage(image: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(images.count > 1 ? "\(selection + 1) of \(images.count)" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if images.indices.contains(selection) {
                    ToolbarItem(placement: .primaryAction) {
                        let image = Image(uiImage: images[selection])
                        ShareLink(item: image, preview: SharePreview("Photo", image: image))
                    }
                }
            }
        }
    }
}

private struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value.magnification, 1), 5)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1 { resetZoom() }
                    }
            )
            // Only pan while zoomed so horizontal swipes still page between photos.
            .simultaneousGesture(scale > 1 ? panGesture : nil)
            .onTapGesture(count: 2) {
                withAnimation(.spring) {
                    if scale > 1 { resetZoom() } else { scale = 2.5; lastScale = 2.5 }
                }
            }
            .accessibilityLabel("Photo")
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func resetZoom() {
        scale = 1; lastScale = 1
        offset = .zero; lastOffset = .zero
    }
}
