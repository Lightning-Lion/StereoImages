//
//  ContentView.swift
//  StereoImages
//
//  Created by 凌嘉徽 on 2024/8/10.
//

import SwiftUI
import RealityKit
import RealityKitContent
import DoubleEye
import PhotosUI

struct ContentView: View {
    @State
    var leftEyeImage:PhotosPickerItem? = nil
    @State
    var rightEyeImage:PhotosPickerItem? = nil
    @State
    var imagePack:StereoImagePack? = nil
    @State
    var loading = false
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    VStack {
                        if let leftEyeImage {
                            Label("Left Eye Image Picked", systemImage: "checkmark")
                        }
                        PhotosPicker("Pick Left Eye Image", selection: $leftEyeImage)
                    }
                    .padding()
                    VStack {
                        if let rightEyeImage {
                            Label("Right Eye Image Picked", systemImage: "checkmark")
                        }
                        PhotosPicker("Pick Right Eye Image", selection: $rightEyeImage)
                    }
                    .padding()
                }
                if let leftEyeImage,let rightEyeImage {
                    Button("Next", action: {
                        loading = true
                        Task {
                            do {
                                let leftUIImage = try await leftEyeImage.loadTransferable(type: Data.self)!
                                let rightUIImage = try await rightEyeImage.loadTransferable(type: Data.self)!
                                self.imagePack = .init(left: .init(data: leftUIImage)!, right: .init(data: rightUIImage)!)
                            } catch {
                                fatalError(error.localizedDescription)
                            }
                            loading = false
                        }
                    })
                    .buttonStyle(.borderedProminent)
                    .disabled(loading)
                    .overlay(alignment: .center) {
                        if loading {
                            ProgressView()
                        }
                    }
                } else {
                    Text("Please pick images before continue.")
                }
                
            }
            .navigationDestination(item: $imagePack) {
                StoereoPhotoView(imagePack: $0)
            }
        }
    }
}

struct StereoImagePack:Identifiable,Hashable {
    var id = UUID()
    var left:UIImage
    var right:UIImage
}

struct StoereoPhotoView: View {
    var imagePack:StereoImagePack
    @State
    var vm = ViewModel()
    var body: some View {
        RealityView { content in
            do {
                let card = try await {
                    var matX = try await ShaderGraphMaterial(named: "/Root/Material",
                                                             from: "Scene.usda",
                                                             in: doubleEyeBundle)
                    
                    let imgLeft = imagePack.left
                    let left =  try await vm.generateMaterial(imgLeft)
                    try matX.setParameter(name: "LeftEye", value: .textureResource(left))
                    
                    let imgRight = imagePack.right
                    let right =  try await vm.generateMaterial(imgRight)
                    try matX.setParameter(name: "RightEye", value: .textureResource(right))
                    
                    
                    //if a image is 1920x1080 the plane size is 0.192x0.108
                    let entity = ModelEntity(mesh: .generatePlane(width: Float(imgLeft.size.width)/10000, height: Float(imgLeft.size.height)/10000, cornerRadius: 0.01))
                    
                    
                    
                    entity.model?.materials = [matX]
                    return entity
                }()
                content.add(card)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        Text("Using physics device to see right eye image.")
            .font(.title)
            .padding()
    }
}

@Observable
class ViewModel {
    func generateMaterial(_ image:UIImage) async throws -> TextureResource {
        if let cgImg = image.cgImage {
            let texture = try await TextureResource(image: cgImg, options: TextureResource.CreateOptions.init(semantic: nil))
            
            return texture
        } else {
            throw ViewError.error1
        }
    }
    enum ViewError:Error,LocalizedError {
        case error1
    }
}


#Preview(windowStyle: .automatic) {
    ContentView()
}
