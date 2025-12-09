import Flutter
import Foundation

#if canImport(MWDATCore)
import MWDATCore
import MWDATCamera
#endif

public class MetaWearablesPlugin: NSObject, FlutterPlugin, UIApplicationDelegate {
  private var api: MetaWearablesHostApiImpl?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let api = MetaWearablesHostApiImpl(binaryMessenger: messenger)
    WearablesHostApiSetup.setUp(binaryMessenger: messenger, api: api)
    let instance = MetaWearablesPlugin()
    instance.api = api
    registrar.addApplicationDelegate(instance)
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    #if canImport(MWDATCore)
    if URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .contains(where: { $0.name == "metaWearablesAction" }) == true {
      Task { _ = try? await Wearables.shared.handleUrl(url) }
      return true
    }
    #endif
    return false
  }
}

private class MetaWearablesHostApiImpl: NSObject, WearablesHostApi {
  private let flutterApi: WearablesFlutterApi
  #if canImport(MWDATCore)
  private var registrationTask: Task<Void, Never>?
  private var streamSession: StreamSession?
  private var streamTasks: [Task<Void, Never>] = []
  private var listenerTokens: [AnyListenerToken] = []
  #endif

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = WearablesFlutterApi(binaryMessenger: binaryMessenger)
  }

  deinit {
    #if canImport(MWDATCore)
    registrationTask?.cancel()
    stopStream()
    #endif
  }

  func initialize() throws {
    #if canImport(MWDATCore)
    try Wearables.configure()
    startRegistrationStream()
    #endif
  }

  func checkPermission(permission: Permission, completion: @escaping (Result<PermissionResult, Error>) -> Void) {
    #if canImport(MWDATCore)
    Task {
      do {
        let status = try await Wearables.shared.checkPermissionStatus(.camera)
        completion(.success(status.toPigeonResult()))
      } catch {
        completion(.failure(error))
        flutterApi.onError(errorInfo: ErrorInfo(code: "permission", message: error.localizedDescription))
      }
    }
    #else
    completion(.success(PermissionResult(status: .error, message: "MWDATCore not linked. Add the Meta Wearables Swift Package to your app target.")))
    #endif
  }

  func requestPermission(permission: Permission, completion: @escaping (Result<PermissionResult, Error>) -> Void) {
    #if canImport(MWDATCore)
    Task {
      do {
        let status = try await Wearables.shared.requestPermission(.camera)
        completion(.success(status.toPigeonResult()))
      } catch {
        completion(.failure(error))
        flutterApi.onError(errorInfo: ErrorInfo(code: "permission", message: error.localizedDescription))
      }
    }
    #else
    completion(.success(PermissionResult(status: .error, message: "MWDATCore not linked. Add the Meta Wearables Swift Package to your app target.")))
    #endif
  }

  func getRegistrationState(completion: @escaping (Result<RegistrationUpdate, Error>) -> Void) {
    #if canImport(MWDATCore)
    completion(.success(Wearables.shared.registrationState.toPigeonUpdate()))
    #else
    completion(.success(RegistrationUpdate(state: .unavailable, description: "MWDATCore not linked.")))
    #endif
  }

  func startRegistration(completion: @escaping (Result<Void, Error>) -> Void) {
    #if canImport(MWDATCore)
    do {
      try Wearables.shared.startRegistration()
      completion(.success(()))
    } catch {
      completion(.failure(error))
      flutterApi.onError(errorInfo: ErrorInfo(code: "registration", message: error.localizedDescription))
    }
    #else
    completion(.success(()))
    #endif
  }

  func startUnregistration(completion: @escaping (Result<Void, Error>) -> Void) {
    #if canImport(MWDATCore)
    do {
      try Wearables.shared.startUnregistration()
      completion(.success(()))
    } catch {
      completion(.failure(error))
      flutterApi.onError(errorInfo: ErrorInfo(code: "unregistration", message: error.localizedDescription))
    }
    #else
    completion(.success(()))
    #endif
  }

  func startStream(config: StreamConfig, completion: @escaping (Result<Void, Error>) -> Void) {
    #if canImport(MWDATCore)
    stopStream()

    let deviceSelector = AutoDeviceSelector(wearables: Wearables.shared)
    let streamConfig = StreamSessionConfig(
      videoCodec: .raw,
      resolution: config.quality.toResolution(),
      frameRate: UInt(config.frameRate)
    )
    let session = StreamSession(streamSessionConfig: streamConfig, deviceSelector: deviceSelector)
    streamSession = session

    streamTasks.append(Task { @MainActor [weak self] in
      guard let self else { return }
      for await state in session.statePublisher {
        flutterApi.onStreamStateChanged(state: state.toPigeon())
      }
    })

    streamTasks.append(Task { @MainActor [weak self] in
      guard let self else { return }
      for await frame in session.videoFramePublisher {
        if let uiImage = frame.makeUIImage(),
           let data = uiImage.jpegData(compressionQuality: 0.6) {
          let videoData = VideoFrameData(data: data, width: Int32(uiImage.size.width), height: Int32(uiImage.size.height))
          flutterApi.onVideoFrame(frame: videoData)
        }
      }
    })

    streamTasks.append(Task { @MainActor [weak self] in
      guard let self else { return }
      for await photo in session.photoDataPublisher {
        let photoData = PhotoData(data: photo.data, format: "jpeg")
        flutterApi.onPhotoCaptured(photo: photoData)
      }
    })

    listenerTokens.append(
      session.errorPublisher.listen { [weak self] error in
        self?.flutterApi.onError(errorInfo: ErrorInfo(code: "stream", message: error.description))
      }
    )

    Task {
      await session.start()
    }
    completion(.success(()))
    #else
    completion(.success(()))
    #endif
  }

  func stopStream() {
    #if canImport(MWDATCore)
    streamTasks.forEach { $0.cancel() }
    streamTasks.removeAll()
    listenerTokens.removeAll()
    Task { await streamSession?.stop() }
    streamSession = nil
    flutterApi.onStreamStateChanged(state: .stopped)
    #endif
  }

  func capturePhoto() {
    #if canImport(MWDATCore)
    streamSession?.capturePhoto(format: .jpeg)
    #endif
  }

  #if canImport(MWDATCore)
  private func startRegistrationStream() {
    registrationTask?.cancel()
    registrationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await state in Wearables.shared.registrationStateStream() {
        flutterApi.onRegistrationStateChanged(update: state.toPigeonUpdate())
      }
    }
  }
  #endif
}

#if canImport(MWDATCore)
private extension PermissionStatus {
  func toPigeonResult() -> PermissionResult {
    switch self {
    case .granted:
      return PermissionResult(status: .granted, message: nil)
    case .denied:
      return PermissionResult(status: .denied, message: nil)
    case .error(let err):
      return PermissionResult(status: .error, message: err.description)
    @unknown default:
      return PermissionResult(status: .error, message: "Unknown permission status")
    }
  }
}

private extension RegistrationState {
  func toPigeonUpdate() -> RegistrationUpdate {
    switch self {
    case .registered:
      return RegistrationUpdate(state: .registered, description: nil)
    case .registering:
      return RegistrationUpdate(state: .registering, description: nil)
    case .unregistered:
      return RegistrationUpdate(state: .unregistered, description: nil)
    case .unregistering:
      return RegistrationUpdate(state: .unregistering, description: nil)
    case .unavailable:
      return RegistrationUpdate(state: .unavailable, description: nil)
    case .error(let error):
      return RegistrationUpdate(state: .error, description: error.description)
    @unknown default:
      return RegistrationUpdate(state: .error, description: "Unknown registration state")
    }
  }
}

private extension StreamSessionState {
  func toPigeon() -> StreamState {
    switch self {
    case .stopped:
      return .stopped
    case .waitingForDevice:
      return .waitingForDevice
    case .starting:
      return .starting
    case .streaming:
      return .streaming
    case .stopping:
      return .stopping
    case .paused:
      return .paused
    @unknown default:
      return .stopped
    }
  }
}

private extension VideoQuality {
  func toResolution() -> StreamingResolution {
    switch self {
    case .low:
      return .low
    case .medium:
      return .medium
    case .high:
      return .high
    }
  }
}
#endif
