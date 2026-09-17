// ====================================================================
// 🔗 API CONFIGURATION — SINGLE SOURCE OF TRUTH
// 📁 lib/config/api_config.dart
//
// ✅ সকল API Base URL এখানে কন্ট্রোল করুন।
// ✅ পুরো প্রোজেক্টে কোথাও hardcode করবেন না।
// ✅ শুধু এই ফাইলের baseUrl / mediaBaseUrl পরিবর্তন করলেই সব ঠিক হয়।
// ====================================================================

class ApiConfig {
  ApiConfig._(); // prevent instantiation

  // ──────────────────────────────────────────────────────────────────
  // 🌐 BASE URLs — LOCAL vs LIVE CONTROLLER
  // ──────────────────────────────────────────────────────────────────

  /// ⚙️ LOCAL TESTING TOGGLE:
  /// - Set [isLocalMode] = `true` to test on your local machine / server.
  /// - Set [isLocalMode] = `false` to use live production site (https://ukearn.com).
  static const bool isLocalMode = false;

  /// 🖥️ LOCAL SERVER URL:
  /// - Real Phone / Wi-Fi Network: 'http://192.168.0.101:8000'
  /// - Android Emulator: 'http://10.0.2.2:8000'
  static const String localServerUrl = 'http://192.168.0.101:8000';


  /// 🌐 LIVE PRODUCTION SERVER URL
  static const String liveServerUrl = 'https://ukearn.com';

  /// Website base URL (media, images, avatar, agent login, etc.)
  static const String mediaBaseUrl = isLocalMode ? localServerUrl : liveServerUrl;

  /// API base URL (all /api/* endpoints)
  static const String baseUrl = '$mediaBaseUrl/api';

  /// Server Mode endpoint (returns current active mode: local vs live)
  static const String serverMode = '$baseUrl/server-mode';

  /// Dynamic server override URL (if fetched dynamically from backend)
  static String? _dynamicMediaBaseUrl;

  /// Get active media base URL (dynamic or static fallback)
  static String get activeMediaBaseUrl => _dynamicMediaBaseUrl ?? mediaBaseUrl;

  /// Get active API base URL (dynamic or static fallback)
  static String get activeBaseUrl => '$activeMediaBaseUrl/api';

  /// Default avatar fallback image
  static String get dynamicDefaultAvatar => '$activeMediaBaseUrl/uploads/avator.jpg';
  static const String defaultAvatar = '$mediaBaseUrl/uploads/avator.jpg';

  /// Agent portal login URL
  static const String agentLoginUrl = '$mediaBaseUrl/agent/login';

  // ──────────────────────────────────────────────────────────────────
  // 1. AUTHENTICATION & PASSWORD RECOVERY
  // ──────────────────────────────────────────────────────────────────
  static String get register            => '$activeBaseUrl/register';
  static String get login               => '$activeBaseUrl/login';
  static String get logout              => '$activeBaseUrl/logout';
  static String get passwordEmail       => '$activeBaseUrl/password/email';
  static String get passwordReset       => '$activeBaseUrl/password/reset';

  // ──────────────────────────────────────────────────────────────────
  // 🔑 V1 FLUTTER INTEGRATION ENDPOINTS
  // ──────────────────────────────────────────────────────────────────
  static String get v1SupportRegister   => '$activeBaseUrl/v1/support/register';
  static String get v1User              => '$activeBaseUrl/v1/user';
  static String get v1LicenseStatus     => '$activeBaseUrl/v1/license/status';
  static String get v1LicenseActivate   => '$activeBaseUrl/v1/license/activate';
  static String get v1SupportConvo      => '$activeBaseUrl/v1/support/conversation';
  static String get v1SupportMessages   => '$activeBaseUrl/v1/support/messages';
  static String get v1QrVerify          => '$activeBaseUrl/v1/qr/verify';


  // ──────────────────────────────────────────────────────────────────
  // 2. USER PROFILE & KYC
  // ──────────────────────────────────────────────────────────────────
  static const String profile         = '$baseUrl/profile';
  static const String profileUpdate   = '$baseUrl/profileupdate';
  static const String profilePhoto    = '$baseUrl/profile/photo';
  static const String changePassword  = '$baseUrl/chagepassword';
  static const String kycSubmit       = '$baseUrl/kycsubmit';
  static const String kycStatus       = '$baseUrl/kycsubmit/kyc-status';
  static const String kycResubmit     = '$baseUrl/kycsubmit/kyc-resubmit';

  // ──────────────────────────────────────────────────────────────────
  // 3. EARNING SYSTEM & AD TASKS
  // ──────────────────────────────────────────────────────────────────
  static const String userEarning       = '$baseUrl/user-earning';
  static const String trackAdView       = '$baseUrl/track-ad-view';
  static const String trackInvalidClick = '$baseUrl/track-invalid-click';
  static const String breakComplete     = '$baseUrl/break-complete';
  static const String claimReward       = '$baseUrl/claim-reward';
  static const String referralStats     = '$baseUrl/referral-stats';
  static const String totalReffer       = '$baseUrl/totalreffer';

  // ──────────────────────────────────────────────────────────────────
  // 4. PACKAGES & PLANS
  // ──────────────────────────────────────────────────────────────────
  static const String packageShow     = '$baseUrl/packageshow';
  static String packageBuy(int id)    => '$baseUrl/packagebuy/$id';
  static const String currentPackage  = '$baseUrl/user/current-package';
  static const String userBalance     = '$baseUrl/user/balance';

  // ──────────────────────────────────────────────────────────────────
  // 5. P2P DEPOSIT
  // ──────────────────────────────────────────────────────────────────
  static const String depositRequest  = '$baseUrl/user/deposit/request';
  static const String depositStatus   = '$baseUrl/user/deposit/status';
  static String depositSubmit(int id) => '$baseUrl/user/deposit/submit/$id';
  static const String userDeposits    = '$baseUrl/userDeposits';
  static String userDepositsByStatus(String s) => '$baseUrl/userDeposits/$s';
  static const String depositCancel   = '$baseUrl/depositecancled';

  // ──────────────────────────────────────────────────────────────────
  // 6. P2P WITHDRAWAL
  // ──────────────────────────────────────────────────────────────────
  static const String withdrawRequest = '$baseUrl/user/withdraw/request';
  static const String withdrawStatus  = '$baseUrl/user/withdraw/status';
  static String withdrawSubmit(int id) => '$baseUrl/user/withdraw/submit/$id';
  static const String withdrawCancel  = '$baseUrl/withdrawcancled';

  // ──────────────────────────────────────────────────────────────────
  // 7. SOCIAL NETWORKING & FRIENDS
  // ──────────────────────────────────────────────────────────────────
  static const String userSearch              = '$baseUrl/user-search';
  static const String friendRequest           = '$baseUrl/user/friend/request';
  static const String cancelFriendReq         = '$baseUrl/cancel/friend/request';
  static const String friendRequestsReceived  = '$baseUrl/user/friend/request/accept/view';
  static const String friendRequestsSent      = '$baseUrl/user/friend/request/sent';
  static const String friendAccept            = '$baseUrl/user/friend/request/accept';
  static const String friendReject            = '$baseUrl/user/friend/request/reject';
  static const String friends                 = '$baseUrl/friends';
  static const String friendsCount            = '$baseUrl/friends/count';
  static const String unfriend                = '$baseUrl/unfriend';

  // ──────────────────────────────────────────────────────────────────
  // 8. USER-TO-USER DIRECT CHAT
  // ──────────────────────────────────────────────────────────────────
  static const String chatList         = '$baseUrl/chat/frontend/list';
  static const String chatMessages     = '$baseUrl/chat/frontend/messages';
  static const String chatSend         = '$baseUrl/chat/frontend/submit';
  static const String chatMarkRead     = '$baseUrl/chat/message/mark-read';
  static const String chatLastMessages = '$baseUrl/chat/last-messages';

  // ──────────────────────────────────────────────────────────────────
  // 9. USER-TO-AGENT SUPPORT CHAT
  // ──────────────────────────────────────────────────────────────────
  static const String agentsList        = '$baseUrl/usertoagentchat/agents';
  static const String agentChatFetch    = '$baseUrl/usertoagentchat/fetch';
  static const String agentChatSend     = '$baseUrl/usertoagentchat/send';
  static const String agentChatMarkRead = '$baseUrl/usertoagentchat/mark-read';

  // ──────────────────────────────────────────────────────────────────
  // 10. USER-TO-ADMIN SUPPORT CHAT
  // ──────────────────────────────────────────────────────────────────
  static const String adminChatFetch    = '$baseUrl/usertoadminchat/fetch';
  static const String adminChatSend     = '$baseUrl/usertoadminchat/send';
  static const String adminChatMarkRead = '$baseUrl/usertoadminchat/mark-read';

  // ──────────────────────────────────────────────────────────────────
  // 11. SOCIAL FEED (POSTS)
  // ──────────────────────────────────────────────────────────────────
  static const String posts          = '$baseUrl/posts';
  static String postById(int id)     => '$baseUrl/posts/$id';
  static String toggleLike(int id)   => '$baseUrl/posts/$id/like';

  // ──────────────────────────────────────────────────────────────────
  // 12. PUSH NOTIFICATIONS
  // ──────────────────────────────────────────────────────────────────
  static const String updateFcmToken  = '$baseUrl/update-fcm-token';
  static const String updateOneSignal = '$baseUrl/update-onesignal-player';
  static const String getNotifications = '$baseUrl/get-notifications';
  static const String markNotifRead   = '$baseUrl/mark-notification-read';
  static const String deleteNotif     = '$baseUrl/delete-notification';

  // ──────────────────────────────────────────────────────────────────
  // 13. PUBLIC CONFIGURATIONS & INFORMATION
  // ──────────────────────────────────────────────────────────────────
  static const String logoSetting       = '$baseUrl/logosetting';
  static const String mailSetting       = '$baseUrl/mailsetting';
  static const String googleAdsApproval = '$baseUrl/googleadsapproval';
  static const String themeChange       = '$baseUrl/themechange';
  static const String support           = '$baseUrl/support';
  static const String howToWork         = '$baseUrl/howtowork';
  static const String homeCards         = '$baseUrl/home-cards';
  static const String privacyPolicy     = '$baseUrl/privacy-policy';

  // ──────────────────────────────────────────────────────────────────
  // 14. MEMBERSHIP / PACKAGE BUY
  // ──────────────────────────────────────────────────────────────────
  static const String membershipPackages = '$baseUrl/packageshow';

  // ──────────────────────────────────────────────────────────────────
  // 🖼️ MEDIA URL HELPERS
  // ──────────────────────────────────────────────────────────────────

  /// Full URL for any media file path stored in DB (e.g. "uploads/photo.jpg")
  static String mediaUrl(String path) {
    if (path.trim().isEmpty) return '';
    String clean = path.trim();

    if (isLocalMode) {
      clean = clean
          .replaceAll('http://127.0.0.1:8000', mediaBaseUrl)
          .replaceAll('http://localhost:8000', mediaBaseUrl)
          .replaceAll('https://127.0.0.1:8000', mediaBaseUrl)
          .replaceAll('https://localhost:8000', mediaBaseUrl);
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    final cleanPath = clean.startsWith('/') ? clean.substring(1) : clean;
    return '$mediaBaseUrl/$cleanPath';
  }

  /// Full URL for avatar images
  static String avatarUrl(String? avatar) {
    if (avatar == null || avatar.trim().isEmpty) return defaultAvatar;

    String clean = avatar.trim();

    if (isLocalMode) {
      clean = clean
          .replaceAll('http://127.0.0.1:8000', mediaBaseUrl)
          .replaceAll('http://localhost:8000', mediaBaseUrl)
          .replaceAll('https://127.0.0.1:8000', mediaBaseUrl)
          .replaceAll('https://localhost:8000', mediaBaseUrl);
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    if (clean.startsWith('/')) {
      clean = clean.substring(1);
    }

    if (clean.startsWith('uploads/')) {
      return '$mediaBaseUrl/$clean';
    }

    if (clean.startsWith('profile/')) {
      return '$mediaBaseUrl/uploads/$clean';
    }

    return '$mediaBaseUrl/uploads/profile/$clean';
  }
}
