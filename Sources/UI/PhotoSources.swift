import PhotosUI
import SwiftUI
import UIKit

/// Where new photos come from.
enum PhotoSource: Identifiable {
    case camera, library
    var id: Self { self }
}

/// The camera, full screen. Hands back the photo taken, or nothing when cancelled.
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPick(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPick(nil) }
    }
}

/// The buttons of a menu that adds photos: they only pick the source, the screen presents it
/// (presentations hung on toolbar items do not always show).
struct PhotoSourceButtons: View {
    @Binding var source: PhotoSource?

    var body: some View {
        if CameraPicker.isAvailable {
            Button { source = .camera } label: { Label("Scatta una foto", systemImage: "camera") }
        }
        Button { source = .library } label: { Label("Scegli dalle foto", systemImage: "photo.on.rectangle") }
    }
}

/// Presents the camera or the photo library when `source` is set, and hands the images back.
struct PhotoSourcePresenter: ViewModifier {
    @Binding var source: PhotoSource?
    var multiple: Bool
    var onImages: ([UIImage]) -> Void

    @State private var picked: [PhotosPickerItem] = []

    private var libraryShown: Binding<Bool> {
        Binding(get: { source == .library }, set: { if !$0, source == .library { source = nil } })
    }

    private var cameraShown: Binding<Bool> {
        Binding(get: { source == .camera }, set: { if !$0, source == .camera { source = nil } })
    }

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: libraryShown, selection: $picked, maxSelectionCount: multiple ? 30 : 1,
                          selectionBehavior: .ordered, matching: .images)
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                picked = []
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    if !images.isEmpty { onImages(images) }
                }
            }
            .fullScreenCover(isPresented: cameraShown) {
                CameraPicker { image in
                    source = nil
                    if let image { onImages([image]) }
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func photoSource(_ source: Binding<PhotoSource?>, multiple: Bool = true, onImages: @escaping ([UIImage]) -> Void) -> some View {
        modifier(PhotoSourcePresenter(source: source, multiple: multiple, onImages: onImages))
    }
}
