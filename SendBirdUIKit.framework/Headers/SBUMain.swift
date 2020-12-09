//
//  SBUMain.swift
//  SendBirdUIKit
//
//  Created by Tez Park on 27/02/2020.
//  Copyright © 2020 SendBird, Inc. All rights reserved.
//

import UIKit
import SendBirdSDK

@objcMembers
public class SBUMain: NSObject {
    
    // MARK: - Initialize
    /// This function is used to initializes SDK with applicationId.
    /// - Parameter applicationId: Application ID
    public static func initialize(applicationId: String) {
        SBUGlobals.ApplicationId = applicationId
        
        if let version = SBUMain.shortVersionString() {
            SBDMain.addExtension(SBUConstant.sbdExtensionKeyUIKit, version: version)
        }
        
        SBDMain.initWithApplicationId(applicationId)
        
        SBULog.info("[Init] UIKit initialized with id: \(applicationId)")
    }
    
    
    // MARK: - Connection
    /// This function is used to connect to the SendBird server.
    ///
    /// Before invoking this function, `CurrentUser` object of `SBUGlobals` claas must be set.
    /// - Parameter completionHandler: The handler block to execute.
    public static func connect(
        completionHandler: @escaping (_ user: SBDUser?, _ error: SBDError?) -> Void
    ) {
        SBULog.info("[Request] Connection to SendBird server")
        
        guard let currentUser = SBUGlobals.CurrentUser else {
            SBULog.error("[Failed] Connection to SendBird server: CurrentUser value is not set")
            completionHandler(SBDMain.getCurrentUser(), nil)
            return
        }
        
        let userId = currentUser.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = currentUser.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        SBDMain.connect(withUserId: userId, accessToken: SBUGlobals.AccessToken) { user, error in
            if let error = error {
                SBULog.error("[Failed] Connection to SendBird server: \(error.localizedDescription)")
                completionHandler(nil, error)
                return
            }
            
            SBULog.info("[Succeed] Connection to SendBird server")
            
            var updatedNickname = nickname
            
            if updatedNickname == nil {
                if user?.nickname?.isEmpty == false {
                    updatedNickname = user?.nickname
                } else {
                    updatedNickname = userId
                }
            }
            
            SBUMain.updateUserInfo(
                nickname: updatedNickname,
                profileUrl: currentUser.profileUrl ?? user?.profileUrl
            ) { error in
                
                guard error == nil else {
                    completionHandler(nil, error)
                    return
                }
                
                #if !targetEnvironment(simulator)
                if let pendingPushToken = SBDMain.getPendingPushToken() {
                    SBULog.info("[Request] Register pending push token to SendBird server")
                    SBUMain.registerPush(deviceToken: pendingPushToken) { success in
                        if !success {
                            SBULog.error("[Failed] Register pending push token to SendBird server")
                        }
                        SBULog.info("[Succeed] Register pending push token to SendBird server")
                    }
                }
                #endif
                
                SBUEmojiManager.loadAllEmojis { _, error in
                    completionHandler(user, error)
                }
                
            }
        }
    }
    
    /// This function is used to check the connection state.
    ///  if connected, returns the SBDUser object, otherwise, call the connect function from the inside.
    /// - Parameter completionHandler: The handler block to execute.
    public static func connectionCheck(
        completionHandler: @escaping (_ user: SBDUser?, _ error: SBDError?) -> Void
    ) {
        SBULog.info("[Check] Connection status")
        
        if SBDMain.getConnectState() == .open {
            completionHandler(SBDMain.getCurrentUser(), nil)
        }
        else {
            SBUMain.connect(completionHandler: completionHandler)
        }
    }
    
    /// This function is used to disconnect
    /// - Parameter completionHandler: The handler block to execute.
    public static func disconnect(completionHandler: (() -> Void)?) {
        SBULog.info("[Request] Disconnection to SendBird server")
        
        SBDMain.disconnect(completionHandler: {
            SBULog.info("[Succeed] Disconnection to SendBird server")
            SBUGlobals.CurrentUser = nil
            completionHandler?()
        })
    }
    
    
    // MARK: - UserInfo
    /// This function is used to update user information.
    /// - Parameters:
    ///   - nickname: Nickname to use for update. If this value is nil, the nickname is not updated.
    ///   - profileUrl: Profile URL to use for update. If this value is nil, the profile is not updated.
    ///   - completionHandler: The handler block to execute.
    public static func updateUserInfo(nickname: String?,
                                      profileUrl: String?,
                                      completionHandler: ((_ error: SBDError?) -> Void)?) {
        SBULog.info("[Request] Update user info")
        SBDMain.updateCurrentUserInfo(
            withNickname: nickname,
            profileUrl: profileUrl
        ) { error in
            self.didFinishUpdateUserInfo(error: error, completionHandler: completionHandler)
        }
    }
    
    /// This function is used to update user information.
    /// - Parameters:
    ///   - nickname: Nickname to use for update. If this value is nil, the nickname is not updated.
    ///   - profileImage: Profile image to use for update. If this value is nil, the profile is not updated.
    ///   - completionHandler: The handler block to execute.
    public static func updateUserInfo(nickname: String?,
                                      profileImage: Data?,
                                      completionHandler: ((_ error: SBDError?) -> Void)?) {
        SBULog.info("[Request] Update user info")
        SBDMain.updateCurrentUserInfo(
            withNickname: nickname,
            profileImage: profileImage,
            progressHandler: nil
        ) { error in
            self.didFinishUpdateUserInfo(error: error, completionHandler: completionHandler)
        }
    }
    
    private static func didFinishUpdateUserInfo(error: SBDError?,
                                                completionHandler: ((_ error: SBDError?) -> Void)?) {
        if let error = error {
            SBULog.error("[Failed] Update user info: \(error.localizedDescription)")
            completionHandler?(error)
            return
        }
        
        SBULog.info("""
            [Succeed]
            Update user info: \(String(SBUGlobals.CurrentUser?.description ?? ""))
            """)
        
        if let user = SBDMain.getCurrentUser() {
            SBUGlobals.CurrentUser = SBUUser(
                userId: user.userId,
                nickname: user.nickname ?? user.userId,
                profileUrl: user.profileUrl
            )
        }
        
        completionHandler?(nil)
    }
    
    
    // MARK: - Common
    @available(*, deprecated, renamed: "shortVersionString()")
    public static func getUIKitVersion() -> String {
        return SBUMain.shortVersionString() ?? ""
    }
    
    /// This function gets UIKit SDK's version string.
    /// - Returns: version string
    public static func versionString() -> String? {
        let bundle = Bundle(identifier: "com.sendbird.uikit")
        if let build = bundle?.infoDictionary?[kCFBundleVersionKey as String] {
            return "\(build)"
        }

        return nil
    }
    
    /// This function gets UIKit SDK's short version string.
    /// - Returns: short version string
    public static func shortVersionString() -> String? {
        let bundle = Bundle(identifier: "com.sendbird.uikit")
        if let shortVersion = bundle?.infoDictionary?["CFBundleShortVersionString"] {
            return "\(shortVersion)"
        }

        return nil
    }

    
    // MARK: - Push Notification
    
    /// This function is used to register push token for using push service on the SendBird server.
    /// - Parameters:
    ///   - deviceToken: Device token
    ///   - completionHandler: The handler block to execute.
    public static func registerPush(deviceToken: Data,
                                    completionHandler: @escaping (_ success: Bool) -> Void) {
        SBULog.info("[Request] Register push token to SendBird server")
        
        #if !targetEnvironment(simulator)
        SBDMain.registerDevicePushToken(deviceToken, unique: true) { status, error in
            switch status {
            case .success:
                SBULog.info("[Succeed] APNs push token is registered.")
                completionHandler(true)
            case .pending:
                SBULog.info("[Response] Push registration is pending.")
                completionHandler(false)
            case .error:
                SBULog.error("""
                    [Failed]
                    APNs registration failed with error: \(String(describing: error ?? nil))
                    """)
                completionHandler(false)
            @unknown default:
                SBULog.error("[Failed] Push registration: unknown default")
                completionHandler(false)
            }
        }
        #else
        completionHandler(false)
        #endif
    }
    
    /// This function is used to unregister push token on the SendBird server.
    /// - Parameter completionHandler: The handler block to execute.
    public static func unregisterPushToken(completionHandler: @escaping (_ success: Bool) -> Void) {
        SBUMain.connectionCheck { user, error in
        guard error == nil else { return }
            
            #if !targetEnvironment(simulator)
            guard let pendingPushToken = SBDMain.getPendingPushToken() else { return }
            SBULog.info("[Request] Unregister push token to SendBird server")
            SBDMain.unregisterPushToken(pendingPushToken) { resonse, error in
                if let error = error {
                    SBULog.error("""
                        [Failed]
                        Push unregistration is fail: \(error.localizedDescription)
                        """)
                    completionHandler(false)
                    return
                }
                
                SBULog.info("[Succeed] Push unregistration is success.")
                completionHandler(true)
            }
            #else
            completionHandler(false)
            #endif
        }
    }
    
    /// This function is used to unregister all push token on the SendBird server.
    /// - Parameter completionHandler: The handler block to execute.
    public static func unregisterAllPushToken(completionHandler: @escaping (_ success: Bool) -> Void) {
        SBUMain.connectionCheck { user, error in
        guard error == nil else { return }
            
            SBULog.info("[Request] Unregister all push token to SendBird server")
            
            SBDMain.unregisterAllPushToken { resonse, error in
                if let error = error {
                    SBULog.error("[Failed] Push unregistration is fail: \(error.localizedDescription)")
                    completionHandler(false)
                    return
                }
                
                SBULog.info("[Succeed] Push unregistration is success.")
                completionHandler(true)
            }
        }
    }
    
    @available(*, deprecated, message: "deprecated in 1.2.2", renamed: "moveToChannel(channelUrl:basedOnChannelList:messageListParams:)")
    public static func openChannel(channelUrl: String,
                                   basedOnChannelList: Bool = true,
                                   messageListParams: SBDMessageListParams? = nil) {
        moveToChannel(
            channelUrl: channelUrl,
            basedOnChannelList: basedOnChannelList,
            messageListParams: messageListParams
        )
    }
    
    /// This is a function that moves the channel that can be called anywhere.
    /// - Parameters:
    ///   - channelUrl: channel url for use in channel.
    ///   - basedOnChannelList: `true` for services based on the channel list. Default value is `true`
    ///   - messageListParams: If there is a messageListParams set directly for use in Channel, set it up here
    /// - Since: 1.2.2
    public static func moveToChannel(channelUrl: String,
                                     basedOnChannelList: Bool = true,
                                     messageListParams: SBDMessageListParams? = nil) {
        guard SBUGlobals.CurrentUser != nil else { return }
        
        var rootViewController = UIApplication.shared.keyWindow?.rootViewController
        var viewController: UIViewController? = nil
        
        if let tabbarController: UITabBarController = rootViewController?.presentedViewController as? UITabBarController {
            rootViewController = tabbarController.selectedViewController
        }
        else if let tabbarController: UITabBarController = rootViewController as? UITabBarController {
            rootViewController = tabbarController.selectedViewController
        }
        
        if let navigationController: UINavigationController = rootViewController?
            .presentedViewController as? UINavigationController {
            
            for subViewController in navigationController.viewControllers {
                if let subViewController = subViewController as? SBUChannelListViewController {
                    navigationController.popToViewController(subViewController, animated: false)
                    viewController = subViewController
                    break
                } else if let subViewController = subViewController as? SBUChannelViewController {
                    viewController = subViewController
                }
            }
        } else if let navigationController: UINavigationController = rootViewController
            as? UINavigationController {
            
            for subViewController in navigationController.viewControllers {
                if let subViewController = subViewController as? SBUChannelListViewController {
                    navigationController.popToViewController(subViewController, animated: false)
                    viewController = subViewController
                    break
                } else if let subViewController = subViewController as? SBUChannelViewController {
                    viewController = subViewController
                }
            }
        }
        
        if let viewController = viewController as? SBUChannelListViewController {
            viewController.showChannel(channelUrl: channelUrl)
        } else if let viewController = viewController as? SBUChannelViewController {
            viewController.loadChannel(channelUrl: channelUrl, messageListParams: messageListParams)
        } else {
            if basedOnChannelList {
                // If based on channelList
                let vc = SBUChannelListViewController()
                let naviVC = UINavigationController(rootViewController: vc)
                rootViewController?.present(naviVC, animated: true, completion: {
                    vc.showChannel(channelUrl: channelUrl)
                })
            } else {
                // If based on channel
                let vc = SBUChannelViewController(
                    channelUrl: channelUrl,
                    messageListParams: messageListParams
                )
                let naviVC = UINavigationController(rootViewController: vc)
                rootViewController?.present(naviVC, animated: true)
            }
        }
    }
    
    /// This is a function that creates and moves the channel that can be called anywhere.
    /// - Parameters:
    ///   - userIds: List of user ids
    ///   - messageListParams: If there is a messageListParams set directly for use in Channel, set it up here
    /// - Since: 1.2.2
    public static func createAndMoveToChannel(userIds: [String],
                                              messageListParams: SBDMessageListParams? = nil) {
        SBULog.info("""
            [Request] Create channel with users,
            User: \(userIds))
            """)
        
        let params = SBDGroupChannelParams()
        params.name = ""
        params.coverUrl = ""
        params.addUserIds(userIds)
        
        SBUGlobalCustomParams.groupChannelParamsCreateBuilder?(params)
        
        self.createAndMoveToChannel(params: params, messageListParams: messageListParams)
    }
    
    /// This is a function that creates and moves the channel that can be called anywhere.
    /// - Parameters:
    ///   - params: `SBDGroupChannelParams` class object
    ///   - messageListParams: If there is a messageListParams set directly for use in Channel, set it up here
    /// - Since: 1.2.2
    public static func createAndMoveToChannel(params: SBDGroupChannelParams,
                                              messageListParams: SBDMessageListParams? = nil) {
        SBDGroupChannel.createChannel(with: params) { channel, error in
            if let error = error {
                SBULog.error("""
                    [Failed] Create channel request:
                    \(String(error.localizedDescription))
                    """)
            }
            
            guard let channelUrl = channel?.channelUrl else {
                SBULog.error("[Failed] Create channel request: There is no channel url.")
                return
            }
            SBULog.info("[Succeed] Create channel: \(channel?.description ?? "")")
            
            SBUMain.moveToChannel(channelUrl: channelUrl, messageListParams: messageListParams)
        }
    }

    
    // MARK: - Logger
    
    /// You can activate log information for debugging.
    ///
    /// - `Objective-C` uses bit masking. (e,g, `.error|.info`)
    /// - `Swift` uses a single type in this function.
    /// - default type: .none
    /// - Parameter type: LogType
    public static func setLogLevel(_ type: LogType) {
        SBULog.logType = type.rawValue
    }
    
    ///  You can activate log information for debugging. (*Swift only*)
    ///
    /// - This function  can uses multiple types.
    /// - default type: .none
    /// - Parameter types: [LogType]
    public static func setLogLevel(_ types: [LogType]) {
        let type = types.map {$0.rawValue}.reduce(0) {$0 + $1}
        SBULog.logType = type
    }
}
