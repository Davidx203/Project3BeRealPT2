//
//  PostPhotoView.swift
//  Project2BeRealClone
//
//  Created by David Perez on 9/22/24.
//
import SwiftUI
import ParseCore
import ImageIO
import CoreLocation
import Photos

struct PostPhotoView: View {
    @State var caption = ""
       @State private var isImagePickerPresented = false
       @State private var selectedImage: UIImage? = nil
       @State private var errorMessage = ""
       @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
       @State private var photoTime: TimeInterval? = nil
       @State private var photoLocation: CLLocation? = nil
       
       @Binding var hasUserPosted: Bool

       var body: some View {
           VStack {
               HStack {
                   Text("Photo")
                       .font(.title)
                       .fontWeight(.bold)
               }
               .frame(maxWidth: .infinity)
               .overlay(content: {
                   HStack {
                       Spacer()
                       Button(action: {
                           postPhoto()
                       }, label: {
                           Text("Post")
                       })
                   }
               })

               TextField("Caption", text: $caption)
                   .padding(5)
                   .background(Color.gray)
                   .clipShape(RoundedRectangle(cornerRadius: 10))

               Button(action: {
                   imagePickerSourceType = .photoLibrary
                   isImagePickerPresented = true
               }, label: {
                   Text("Select Photo")
               })
               .frame(maxWidth: .infinity)
               .padding(8)
               .background(Color.blue.opacity(0.5))
               .clipShape(RoundedRectangle(cornerRadius: 5))
               
               Button(action: {
                   if UIImagePickerController.isSourceTypeAvailable(.camera) {
                       imagePickerSourceType = .camera
                       isImagePickerPresented = true
                   } else {
                       errorMessage = "Camera not available on this device."
                   }
               }, label: {
                   Text("Open Camera")
               })
               .frame(maxWidth: .infinity)
               .padding(8)
               .background(Color.blue.opacity(0.5))
               .clipShape(RoundedRectangle(cornerRadius: 5))

               if let image = selectedImage {
                   Image(uiImage: image)
                       .resizable()
                       .scaledToFit()
                       .frame(height: 200)
                       .clipShape(RoundedRectangle(cornerRadius: 10))
                       .padding()
               }
               
               Spacer()

               if !errorMessage.isEmpty {
                   Text(errorMessage)
                       .foregroundColor(.red)
                       .padding()
               }
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
           .padding(35)
           .foregroundColor(.white)
           .background(Color.black.ignoresSafeArea())
           .sheet(isPresented: $isImagePickerPresented) {
               ImagePicker(selectedImage: $selectedImage, sourceType: imagePickerSourceType, photoTime: $photoTime, photoLocation: $photoLocation)
           }
    }

    func postPhoto() {
        guard let image = selectedImage else {
            errorMessage = "Please select a photo."
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Error converting image."
            return
        }

        let file = PFFileObject(name: "photo.jpg", data: imageData)

        guard let currentUser = PFUser.current() else {
            errorMessage = "Error: No user is logged in."
            return
        }

        let photoPost = PFObject(className: "PhotoPost")
        photoPost["caption"] = caption
        photoPost["username"] = currentUser.username
        photoPost["photo"] = file

        if let photoTime = photoTime {
            photoPost["photoTime"] = photoTime
        }
        if let photoLocation = photoLocation {
            photoPost["photoLocation"] = PFGeoPoint(location: photoLocation)
        }

        photoPost.saveInBackground { (success, error) in
            if let error = error {
                errorMessage = "Error posting photo: \(error.localizedDescription)"
            } else if success {
                errorMessage = "Photo posted successfully!"
                hasUserPosted = true
            }
        }
    }

    // Helper function to format TimeInterval into a readable date and time
    func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium  // Choose a style for the date part
        formatter.timeStyle = .short   // Choose a style for the time part
        return formatter.string(from: date)
    }
}




struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Binding var photoTime: TimeInterval?  // Change from Date? to TimeInterval
    @Binding var photoLocation: CLLocation?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image

                // Extract metadata using PHAsset if available
                if #available(iOS 11.0, *) {
                    if let asset = info[.phAsset] as? PHAsset {
                        // Convert creation date to TimeInterval
                        if let creationDate = asset.creationDate {
                            parent.photoTime = creationDate.timeIntervalSince1970
                        }
                        parent.photoLocation = asset.location
                    }
                } else {
                    print("PHAsset is not available on this iOS version.")
                }
            }
            picker.dismiss(animated: true)
        }
    }
}


#Preview {
    PostPhotoView(hasUserPosted: .constant(false))
}
