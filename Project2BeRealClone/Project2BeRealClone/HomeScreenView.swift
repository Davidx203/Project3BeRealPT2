//
//  HomeScreenView.swift
//  Project2BeRealClone
//
//  Created by David Perez on 9/22/24.
//

import SwiftUI
import ParseCore

struct HomeScreenView: View {
    @State private var photos = [PhotoPostModel]()
    @State private var isRefreshing = false
    @State private var hasUserPosted = false
    @Environment(\.presentationMode) var presentationMode  // To dismiss view
    var usernameLoginIn: String
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "person.2.fill")
                    .clipShape(Circle())
                Spacer()
                Text("BeReal.")
                Spacer()
                Button("Logout", action: logOut)
                    .font(.subheadline)
            }
            .font(.title)
            
            ScrollView {
                NavigationLink(destination: PostPhotoView(hasUserPosted: $hasUserPosted)) {
                    Text("Post a Photo")
                        .fontWeight(.bold)
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                ForEach(photos) { photo in
                    if hasUserPosted && isPhotoVisible(photo) {
                        PhotoRowView(
                            username: photo.username,
                            caption: photo.caption,
                            date:  Date(timeIntervalSince1970: photo.photoTime),  // Convert TimeInterval to Date
                            image: photo.image,
                            showBlur: false,
                            photoId: photo.id,
                            currentUsername: usernameLoginIn
                        )
                    } else {
                        PhotoRowView(
                            username: photo.username,
                            caption: photo.caption,
                            date: Date(timeIntervalSince1970: photo.photoTime),  // Convert TimeInterval to Date
                            image: photo.image,
                            showBlur: true,
                            photoId: photo.id,
                            currentUsername: usernameLoginIn
                        )
                    }
                }
            }
            .refreshable(action: fetchPhotos)
            //.onAppear(perform: fetchPhotos)
        }
        .padding(35)
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: {
            fetchPhotos()
        })
    }
    
    func logOut() {
        PFUser.logOutInBackground { error in
            if let error = error {
                print("Error logging out: \(error.localizedDescription)")
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    struct PhotoPostModel: Identifiable {
        let id: String
        let caption: String
        let username: String
        let photoTime: TimeInterval  // Store time as TimeInterval
        let image: UIImage
    }
    
    func fetchPhotos() {
        let query = PFQuery(className: "PhotoPost")
        query.order(byDescending: "createdAt")
        query.findObjectsInBackground { (objects, error) in
            if let objects = objects {
                var fetchedPhotos: [PhotoPostModel] = []
                let dispatchGroup = DispatchGroup()
                
                for object in objects {
                    dispatchGroup.enter()
                    
                    if let file = object["photo"] as? PFFileObject {
                        file.getDataInBackground { (data, error) in
                            if let data = data, let image = UIImage(data: data) {
                                // Retrieve stored photoTime and set default value if unavailable
                                let photoTime = object["photoTime"] as? TimeInterval ?? Date().timeIntervalSince1970
                                
                                let photoPostModel = PhotoPostModel(
                                    id: object.objectId!,
                                    caption: object["caption"] as? String ?? "",
                                    username: object["username"] as? String ?? "",
                                    photoTime: photoTime,  // Use photoTime from backend
                                    image: image
                                )
                                fetchedPhotos.append(photoPostModel)
                            } else {
                                print("Error fetching image: \(error?.localizedDescription ?? "Unknown error")")
                            }
                            dispatchGroup.leave()
                        }
                    } else {
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    photos = fetchedPhotos
                    isRefreshing = false
                }
            } else {
                print("Error fetching photos: \(error?.localizedDescription ?? "Unknown error")")
                isRefreshing = false
            }
        }
    }
    
    func isPhotoVisible(_ photo: PhotoPostModel) -> Bool {
        let currentTime = Date().timeIntervalSince1970
        let timeInterval = currentTime - photo.photoTime
        return timeInterval < 24 * 60 * 60  // 24 hours in seconds
    }
}





struct PhotoRowView: View {
    var username: String
    var caption: String
    var date: Date
    var image: UIImage
    var showBlur: Bool
    var photoId: String
    var currentUsername: String
    
    var photoDate: Date?
    var latitude: Double?
    var longitude: Double?
    
    struct Comment: Identifiable {
        let id: String
        let content: String
        let username: String
        let createdAt: Date
    }
    
    @State private var comments: [Comment] = []  // State variable to hold the comments
    @State private var newComment = ""           // State for new comment text
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(username)
                    .font(.headline)
                Spacer()
                if let photoDate = photoDate {
                    Text(photoDate, style: .date)
                        .font(.caption)
                } else {
                    Text(date, style: .time)
                        .font(.caption)
                }
                
                Text("Miami, Florida")
                    .font(.caption)
            }
            .padding(.bottom, 5)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .blur(radius: showBlur ? 20 : 0)
            
            Text(caption)
                .font(.body)
                .padding(.vertical)
            
            Divider()
            
            // Comments Section
            VStack(alignment: .leading) {
                Text("Comments")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                ForEach(comments) { comment in
                    HStack {
                        Text(comment.username)
                            .fontWeight(.bold)
                        Text(comment.content)
                    }
                    .padding(.vertical, 2)
                }
                
                // New Comment Input
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundStyle(.black)
                    Button(action: {addComment(username: currentUsername)}) {
                        Text("Post")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
        .onAppear {
            fetchComments()
        }
    }
    
    // Function to fetch comments for the current post from Parse
    private func fetchComments() {
        let query = PFQuery(className: "Comment")
        query.whereKey("photoId", equalTo: photoId) // Replace with actual photo ID
        query.order(byDescending: "createdAt")
        query.findObjectsInBackground { (objects, error) in
            if let objects = objects {
                comments = objects.compactMap { object in
                    if let content = object["content"] as? String,
                       let username = object["username"] as? String,
                       let createdAt = object.createdAt {
                        return Comment(
                            id: object.objectId ?? UUID().uuidString,
                            content: content,
                            username: username,
                            createdAt: createdAt
                        )
                    }
                    return nil
                }
            } else {
                print("Error fetching comments: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // Function to add a new comment
    private func addComment(username: String) {
        guard !newComment.isEmpty else { return }
        
        let commentObject = PFObject(className: "Comment")
        commentObject["content"] = newComment
        commentObject["username"] = username // Replace with actual current user's username
        commentObject["photoId"] = photoId // Replace with the actual photo post ID
        
        commentObject.saveInBackground { (success, error) in
            if success {
                // Fetch comments again to update the list
                fetchComments()
                newComment = ""
            } else {
                print("Error adding comment: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

#Preview {
    HomeScreenView(usernameLoginIn: "Test")
}

