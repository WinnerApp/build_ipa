import ArgumentParser
import SwiftShell
import Foundation
import Alamofire


struct BuildIpa: ParsableCommand {
    
    enum BuildModel: String, EnumerableFlag {
        case debug
        case profile
        case release
    }
    
    @Flag(help: "编译的类型")
    var mode:BuildModel
    
    @Argument(help:"设置主要的版本号 比如 1.0.0")
    var buildName:String
    
    @Flag(help: "是否上传 Zealot 默认开启")
    var uploadZealot: Bool = false
    
    @Option(help: "请输入自定义的导出方法")
    var exportMethod:String?
    
    @Option(help: "请输入自定义 ipa 路径")
    var ipaPath:String?
    
    
    mutating func run() throws {
        var context = CustomContext()
        context.env = ProcessInfo.processInfo.environment
        let configuration = try Configuration(uploadZealot: uploadZealot)
        let pwd = configuration.pwd
        let buildNumber = "\(Int(Date().timeIntervalSince1970))"
        context.currentdirectory = pwd
        
        var _ipaPath:String = ""
        if let ipaPath {
            _ipaPath = ipaPath
        } else {
            try runAndPrint("flutter",
                            "build",
                            "ipa",
                            "--\(mode.rawValue)",
                            "--build-name",
                            buildName,
                            "--build-number",
                            buildNumber
            )
            context.currentdirectory = pwd + "/ios"
            var _exportMethod = "ad-hoc"
            if mode == .release {
                _exportMethod = "app-store"
            }
            _exportMethod = exportMethod ?? _exportMethod
            try context.runAndPrint("fastlane",
                                    "beta",
                                    "archive_path:\(pwd)/build/ios/archive/Runner.xcarchive",
                                    "export_method:\(_exportMethod)")
            _ipaPath = "\(pwd)/ios/Runner.ipa"
        }
        
        
        if uploadZealot {
            try uploadApk(ipaFile: _ipaPath,
                          buildNumber: buildNumber,
                          context: context,
                          pwd: pwd)
        }
    }
    
    func uploadApk(ipaFile:String,
                   buildNumber:String,
                   context:CustomContext,
                   pwd:String) throws {
        let home = try Configuration(uploadZealot: uploadZealot).home
        guard FileManager.default.fileExists(atPath: ipaFile) else {
            throw "\(ipaFile)不存在,请检查编译命令"
        }
        let apkCachePath = "\(home)/Library/Caches/ipa"
        try createDirectoryIfNotExit(path: apkCachePath)
        let toIpaFile = "\(apkCachePath)/app-\(mode.rawValue)-\(buildNumber).ipa"
        try FileManager.default.copyItem(atPath: ipaFile, toPath: toIpaFile)
        let changelog:String
        if let data = FileManager.default.contents(atPath: "\(pwd)/git.log"),
           let log = String(data: data, encoding: .utf8) {
            changelog = log
        } else if let gitLog = ProcessInfo.processInfo.environment["GIT_LOG"] {
            changelog = gitLog
        } else {
            changelog = ""
        }
        print("正在将APK上传到Zealot服务")
        let isOK = try uploadApkInZealot(ipaFile: ipaFile, changeLog: changelog)
        guard isOK else {
            SwiftShell.exit(errormessage: "上传失败!")
        }
        print("上传APK完毕")
    }
    
    func createDirectoryIfNotExit(path:String) throws {
        var isDirectory:ObjCBool = .init(false)
        guard !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            if !isDirectory.boolValue {
                throw "\(path)已经存在，但不是一个文件夹"
            }
            return
        }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path),
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    }
    

    func uploadApkInZealot(ipaFile:String, changeLog:String) throws -> Bool {
        let zealotToken = try Configuration(uploadZealot: uploadZealot).zealotToken
        let channelKey = try Configuration(uploadZealot: uploadZealot).zealotChannelKey
        let uploadHost = try Configuration(uploadZealot: uploadZealot).zealotHost
        let semaphore = DispatchSemaphore(value: 0)
        let uploadUrl = "\(uploadHost)/api/apps/upload?token=\(zealotToken)"
        let mode = mode != .release ? "adhoc" : "release"
        var isOK = false
        let domain = uploadHost.replacingOccurrences(of: "https://", with: "")
        let trustManager = ServerTrustManager(evaluators: [domain:DisabledTrustEvaluator()])
        let session = Session(serverTrustManager:trustManager)
        /// 修改超时时间从 10 分钟到 30 分钟 防止一些包大小比较大
        session.sessionConfiguration.timeoutIntervalForRequest = 30 * 60
        session.upload(multipartFormData: { fromData in
            print("""
            channel_key \(channelKey)
            release_type \(mode)
            changelog \(changeLog)
            """)
            if let data = channelKey.data(using: .utf8) {
                fromData.append(data, withName: "channel_key")
            }
            if let data = mode.data(using: .utf8) {
                fromData.append(data, withName: "release_type")
            }
            if let data = changeLog.data(using: .utf8) {
                fromData.append(data, withName: "changelog")
            }
            if let data = try? Data(contentsOf: URL(fileURLWithPath: ipaFile)) {
                fromData.append(data, withName: "file", fileName: ipaFile)
            }
        }, to: uploadUrl).uploadProgress(queue:DispatchQueue.global(qos: .background)) { progress in
            print("\(progress.fractionCompleted * 100)% 已上传:\(progress.completedUnitCount) 总共大小:\(progress.totalUnitCount)")
        }.response(queue: DispatchQueue.global(qos: .background)) { response in
            print(response.debugDescription)
            if let code = response.response?.statusCode {
                isOK = code == 201
            }
            semaphore.signal()
        }
        

        let result = semaphore.wait(timeout: .now() + 15 * 60)
        return result == .success && isOK
    }
}

BuildIpa.main()

struct JobInfo: Codable {
    let changeSet:ChangeSet?
}

extension JobInfo {
    struct ChangeSet: Codable {
        let items:[Item]
    }
}

extension JobInfo.ChangeSet {
    struct Item: Codable {
        let comment:String
    }
}
