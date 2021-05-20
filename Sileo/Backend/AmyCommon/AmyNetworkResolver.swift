//
//  AmyNetworkResolver.swift
//  Aemulo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit

final class AmyNetworkResolver {
    
    static let shared = AmyNetworkResolver()
    
    var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AmyCache")
    }
    
    var downloadCache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AmyCache").appendingPathComponent("DownloadCache")
    }
    
    var memoryCache = [String: UIImage]()
    
    public func clearCache() {
        if cacheDirectory.dirExists {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        if downloadCache.dirExists {
            try? FileManager.default.removeItem(at: downloadCache)
        }
        setupCache()
    }
    
    public func setupCache() {
        if !cacheDirectory.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: cacheDirectory.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
        }
        if !downloadCache.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: downloadCache.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
            
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path),
           !contents.isEmpty {
            var yes = DateComponents()
            yes.hour = -1
            let weekOld = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
            for cached in contents {
                guard let attr = try? FileManager.default.attributesOfItem(atPath: cached),
                      let date = attr[FileAttributeKey.modificationDate] as? Date else { continue }
                if weekOld > date {
                    try? FileManager.default.removeItem(atPath: cached)
                }
            }
        }
        
        if !downloadCache.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: downloadCache.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: downloadCache.path),
           !contents.isEmpty {
            var yes = DateComponents()
            yes.hour = -1
            let hourOld = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
            for cached in contents {
                guard let attr = try? FileManager.default.attributesOfItem(atPath: cached),
                      let date = attr[FileAttributeKey.modificationDate] as? Date else { continue }
                if hourOld > date {
                    try? FileManager.default.removeItem(atPath: cached)
                }
            }
        }
    }
 
    init() {
        setupCache()
    }

    class private func skipNetwork(_ url: URL) -> Bool {
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attr[FileAttributeKey.modificationDate] as? Date {
            var yes = DateComponents()
            yes.day = -1
            let yesterday = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
            if date > yesterday {
                return true
            }
        }
        return false
    }
    
    class public func dict(request: URLRequest, cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        var pastData: Data?
        if cache {
            if let url = request.url {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                if let data = try? Data(contentsOf: path),
                   let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if skipNetwork(path) {
                        return completion(true, dict)
                    } else {
                        pastData = data
                        completion(true, dict)
                    }
                }
            }
        }
        AmyNetworkResolver.request(request) { success, data -> Void in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                if let url = request.url {
                    let encoded = url.absoluteString.toBase64
                    let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                    try? data.write(to: path)
                }
            }
            if pastData == data { return }
            do {
                let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] ?? [String: Any]()
                return completion(true, dict)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func dict(url: String?, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.dict(url: url, method: method, headers: headers, json: json, cache: cache) { success, dict -> Void in
            completion(success, dict)
        }
    }
    
    class public func dict(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        var pastData: Data?
        if cache {
            let encoded = url.absoluteString.toBase64
            let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
            if let data = try? Data(contentsOf: path),
               let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                if skipNetwork(path) {
                    return completion(true, dict)
                } else {
                    pastData = data
                    completion(true, dict)
                }
            }
        }

        AmyNetworkResolver.request(url: url, method: method, headers: headers, json: json) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                try? data.write(to: path)
            }
            if pastData == data { return }
            do {
                let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] ?? [String: Any]()
                return completion(true, dict)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func array(request: URLRequest, cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        var pastData: Data?
        if cache {
            if let url = request.url {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                if let data = try? Data(contentsOf: path),
                   let arr = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] {
                    if skipNetwork(path) {
                        return completion(true, arr)
                    } else {
                        pastData = data
                        completion(true, arr)
                    }
                }
            }
        }
        AmyNetworkResolver.request(request) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                if let url = request.url {
                    let encoded = url.absoluteString.toBase64
                    let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                    try? data.write(to: path)
                }
            }
            if pastData == data { return }
            do {
                let arr = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] ?? [[String: Any]]()
                return completion(true, arr)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func array(url: String?, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.array(url: url, method: method, headers: headers, json: json, cache: cache) { success, array -> Void in
            return completion(success, array)
        }
    }
    
    class public func array(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        var pastData: Data?
        if cache {
            let encoded = url.absoluteString.toBase64
            let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
            if let data = try? Data(contentsOf: path),
               let arr = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] {
                if skipNetwork(path) {
                    return completion(true, arr)
                } else {
                    pastData = data
                    completion(true, arr)
                }
            }
        }
        AmyNetworkResolver.request(url: url, method: method, headers: headers, json: json) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                try? data.write(to: path)
            }
            if pastData == data { return }
            do {
                let arr = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] ?? [[String: Any]]()
                return completion(true, arr)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func data(request: URLRequest, cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        var pastData: Data?
        if cache {
            if let url = request.url {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                if let data = try? Data(contentsOf: path) {
                    if skipNetwork(path) {
                        return completion(true, data)
                    } else {
                        pastData = data
                        completion(true, data)
                    }
                }
            }
        }
        AmyNetworkResolver.request(request) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                if let url = request.url {
                    let encoded = url.absoluteString.toBase64
                    let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                    try? data.write(to: path)
                }
            }
            if pastData == data { return }
            completion(true, data)
        }
    }
    
    class public func data(url: String?, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.data(url: url, method: method, headers: headers, json: json, cache: cache) { success, data -> Void in
            return completion(success, data)
        }
    }
    
    class public func data(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], cache: Bool = false, _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        var pastData: Data?
        if cache {
            let encoded = url.absoluteString.toBase64
            let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
            if let data = try? Data(contentsOf: path) {
                if skipNetwork(path) {
                    return completion(true, data)
                } else {
                    pastData = data
                    completion(true, data)
                }
            }
        }
        AmyNetworkResolver.request(url: url, method: method, headers: headers, json: json) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            if cache {
                let encoded = url.absoluteString.toBase64
                let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("\(encoded).json")
                try? data.write(to: path)
            }
            if pastData == data { return }
            completion(true, data)
        }
    }
    
    class private func request(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if !json.isEmpty,
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            request.httpBody = jsonData
            request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data {
                return completion(true, data)
            }
            return completion(false, nil)
        }
        task.resume()
    }
    
    class private func request(_ request: URLRequest, _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data {
                return completion(true, data)
            }
            return completion(false, nil)
        }
        task.resume()
    }
    
    internal func image(_ url: String, method: String = "GET", headers: [String: String] = [:], cache: Bool = true, scale: CGFloat? = nil, size: CGSize? = nil, _ completion: @escaping ((_ refresh: Bool, _ image: UIImage?) -> Void)) -> UIImage? {
        guard let url = URL(string: url) else { completion(false, nil); return nil }
        return self.image(url, method: method, headers: headers, cache: cache, scale: scale, size: size) { refresh, image in
            completion(refresh, image)
        }
    }
    
    internal func image(_ url: URL, method: String = "GET", headers: [String: String] = [:], cache: Bool = true, scale: CGFloat? = nil, size: CGSize? = nil, _ completion: @escaping ((_ refresh: Bool, _ image: UIImage?) -> Void)) -> UIImage? {
        if String(url.absoluteString.prefix(7)) == "file://" {
            completion(false, nil)
            return nil
        }
        var pastData: Data?
        let encoded = url.absoluteString.toBase64
        if cache,
           let memory = memoryCache[encoded] {
            completion(false, nil)
            return memory
        }
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        if path.exists {
            if let data = try? Data(contentsOf: path) {
                if var image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                    if let downscaled = GifController.downsample(image: image, to: size, scale: scale) {
                        image = downscaled
                    }
                    if cache {
                        memoryCache[encoded] = image
                        pastData = data
                        if AmyNetworkResolver.skipNetwork(path) {
                            completion(false, nil)
                        }
                    }
                    return image
                }
            }
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ -> Void in
            if let data = data,
               var image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                if let downscaled = GifController.downsample(image: image, to: size, scale: scale) {
                    image = downscaled
                }
                completion(pastData != data, image)
                if cache {
                    self?.memoryCache[encoded] = image
                    do {
                        try data.write(to: path, options: .atomic)
                    } catch {
                        print("Error saving to \(path.absoluteString) with error: \(error.localizedDescription)")
                    }
                }
            } else {
                completion(false, nil)
            }
        }
        task.resume()
        return nil
    }
    
    internal func saveCache(_ url: URL, data: Data) {
        if String(url.absoluteString.prefix(7)) == "file://" {
            return
        }
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        do {
            try data.write(to: path, options: .atomic)
        } catch {
            print("Error saving to \(path.absoluteString) with error: \(error.localizedDescription)")
        }
    }
    
    internal func imageCache(_ url: URL, scale: CGFloat? = nil, size: CGSize? = nil) -> (Bool, UIImage?) {
        if String(url.absoluteString.prefix(7)) == "file://" {
            return (true, nil)
        }
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        if let data = try? Data(contentsOf: path) {
            if var image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                if let downscaled = GifController.downsample(image: image, to: size, scale: scale) {
                    image = downscaled
                }
                return (!AmyNetworkResolver.skipNetwork(path), image)
            }
        }
        return (true, nil)
    }
}

extension String {
    var toBase64: String {
        return Data(self.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "=", with: "")
    }
}

extension FileManager {
    func directorySize(_ dir: URL) -> Int {
        guard let enumerator = self.enumerator(at: dir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { return 0 }
        var bytes = 0
        for case let url as URL in enumerator {
            bytes += url.size
        }
        return bytes
    }
    
    func sizeString(_ dir: URL) -> String {
        let bytes = Float(directorySize(dir))
        let kiloBytes = bytes / Float(1024)
        if kiloBytes <= 1024 {
            return "\(String(format: "%.1f", kiloBytes)) KB"
        }
        let megaBytes = kiloBytes / Float(1024)
        if megaBytes <= 1024 {
            return "\(String(format: "%.1f", megaBytes)) MB"
        }
        let gigaBytes = megaBytes / Float(1024)
        return "\(String(format: "%.1f", gigaBytes)) GB"
    }
}

extension URL {
    var size: Int {
        guard let values = try? self.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { return 0 }
        return values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
    }
}

// swiftlint:disable type_name
public class Amy: Any {}
