//
//  ViewController.swift
//  FlowerSnap
//
//  Created by Jonathan Cheth on 5/13/25.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var uiImageView: UIImageView!
    @IBOutlet weak var flowerLabel: UILabel!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
        flowerLabel.isHidden = true
    }

    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let userPickedImage = info[.originalImage] as? UIImage {
            uiImageView.image = userPickedImage

            guard let convertedCIImage = CIImage(image: userPickedImage) else {
                fatalError("Could not convert UIImage to CIImage.")
            }

            detect(image: convertedCIImage)
        }

        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func detect(image: CIImage) {
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Can't load CoreML model.")
        }

        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let result = request.results?.first as? VNClassificationObservation else {
                fatalError("Could not classify image.")
            }

            let flowerName = result.identifier.capitalized

            DispatchQueue.main.async {
                self.navigationItem.title = flowerName
                self.fetchFlowerInfo(flowerName: result.identifier)
            }
        }

        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("CoreML classification error: \(error)")
        }
    }
    
    func fetchFlowerInfo(flowerName: String) {
        let urlString = "https://en.wikipedia.org/w/api.php"
        let queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "extracts|pageimages"),
            URLQueryItem(name: "exintro", value: ""),
            URLQueryItem(name: "explaintext", value: ""),
            URLQueryItem(name: "titles", value: flowerName),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "pithumbsize", value: "500"),
            URLQueryItem(name: "indexpageids", value: "")
        ]

        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async {
                    self.flowerLabel.text = "Failed to fetch data."
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(WikipediaResponse.self, from: data)
                if let pageID = decoded.query.pageids.first,
                   let page = decoded.query.pages[pageID] {
                    DispatchQueue.main.async {
                        self.flowerLabel.isHidden = false
                        self.flowerLabel.text = page.extract
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.flowerLabel.text = "Error decoding data."
                }
            }
        }.resume()
    }

    
}

struct WikipediaResponse: Codable {
    let query: Query
}

struct Query: Codable {
    let pageids: [String]
    let pages: [String: Page]
}

struct Page: Codable {
    let extract: String
}

