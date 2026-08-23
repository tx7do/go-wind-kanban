// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en_US locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en_US';

  static String m0(count) => "Bookmarked ${count} articles";

  static String m1(count) => "Comments (${count})";

  static String m2(days) => "${days} days ago";

  static String m3(month, day) => "${month}/${day}";

  static String m4(query) => "No results found for \"${query}\"";

  static String m5(count) => "${count} posts";

  static String m6(count) => "${count} articles";

  static String m7(count) => "Related Articles (${count})";

  static String m8(count) => "${count} related articles";

  static String m9(weeks) => "${weeks} weeks ago";

  static String m10(year, month, day) => "${year}/${month}/${day}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "aboutFeature1Desc": MessageLookupByLibrary.simpleMessage(
      "Organize work with boards, columns and cards through an intuitive interface",
    ),
    "aboutFeature1Title": MessageLookupByLibrary.simpleMessage("Kanban Boards"),
    "aboutFeature2Desc": MessageLookupByLibrary.simpleMessage(
      "Built-in internationalization to serve a global audience effortlessly",
    ),
    "aboutFeature2Title": MessageLookupByLibrary.simpleMessage(
      "Multi-language Support",
    ),
    "aboutFeature3Desc": MessageLookupByLibrary.simpleMessage(
      "Seamless experience across Web, iOS, Android and desktop platforms",
    ),
    "aboutFeature3Title": MessageLookupByLibrary.simpleMessage(
      "Cross-platform",
    ),
    "aboutSubtitle": MessageLookupByLibrary.simpleMessage(
      "A modern kanban board system powered by Go and Flutter",
    ),
    "aboutTechStack": MessageLookupByLibrary.simpleMessage("Built with"),
    "allLoaded": MessageLookupByLibrary.simpleMessage("— All Loaded —"),
    "allPosts": MessageLookupByLibrary.simpleMessage("All Posts"),
    "appName": MessageLookupByLibrary.simpleMessage("GoWind Kanban"),
    "appearance": MessageLookupByLibrary.simpleMessage("Appearance"),
    "archived": MessageLookupByLibrary.simpleMessage("Archived"),
    "backToHome": MessageLookupByLibrary.simpleMessage("Back to Home"),
    "boardName": MessageLookupByLibrary.simpleMessage("Board Name"),
    "boardNoColumns": MessageLookupByLibrary.simpleMessage(
      "This board has no columns",
    ),
    "boards": MessageLookupByLibrary.simpleMessage("Boards"),
    "boardsOffline": MessageLookupByLibrary.simpleMessage("Boards (Offline)"),
    "bookmarkHint": MessageLookupByLibrary.simpleMessage(
      "Tap the bookmark button while reading to save",
    ),
    "bookmarkedCount": m0,
    "bookmarkedPostsLabel": MessageLookupByLibrary.simpleMessage("Bookmarked"),
    "bookmarks": MessageLookupByLibrary.simpleMessage("Bookmarks"),
    "browseCategories": MessageLookupByLibrary.simpleMessage(
      "Browse Categories",
    ),
    "browseHistory": MessageLookupByLibrary.simpleMessage("Browse History"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cardTitle": MessageLookupByLibrary.simpleMessage("Card Title"),
    "clear": MessageLookupByLibrary.simpleMessage("Clear"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorHint": MessageLookupByLibrary.simpleMessage(
      "Color (e.g. red/blue/#hex)",
    ),
    "columnName": MessageLookupByLibrary.simpleMessage("Column Name"),
    "comments": MessageLookupByLibrary.simpleMessage("Comments"),
    "commentsCount": m1,
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "contactCommunity": MessageLookupByLibrary.simpleMessage("Community"),
    "contactCommunityDesc": MessageLookupByLibrary.simpleMessage(
      "Join our developer community on GitHub to report issues, share ideas, and contribute to the project.",
    ),
    "contactEmail": MessageLookupByLibrary.simpleMessage("Email"),
    "contactEmailDesc": MessageLookupByLibrary.simpleMessage(
      "You can reach us via email at support@gowind.dev for any questions, suggestions or feedback. We typically respond within 1-2 business days.",
    ),
    "contactUs": MessageLookupByLibrary.simpleMessage("Contact Us"),
    "contactWebsite": MessageLookupByLibrary.simpleMessage("Website"),
    "contactWebsiteDesc": MessageLookupByLibrary.simpleMessage(
      "Visit our official website gowind.dev for the latest updates, documentation, and community resources.",
    ),
    "coverColor": MessageLookupByLibrary.simpleMessage("Cover Color"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createFailed": MessageLookupByLibrary.simpleMessage("Creation Failed"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "darkMode": MessageLookupByLibrary.simpleMessage("Dark Mode"),
    "daysAgo": m2,
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteBoard": MessageLookupByLibrary.simpleMessage("Delete Board"),
    "deleteBoardConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this board? This action cannot be undone.",
    ),
    "deleteColumn": MessageLookupByLibrary.simpleMessage("Delete Column"),
    "deleteColumnConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this column and all its cards? This action cannot be undone.",
    ),
    "deleteFailed": MessageLookupByLibrary.simpleMessage("Delete Failed"),
    "deleteLabel": MessageLookupByLibrary.simpleMessage("Delete Label"),
    "deleteLabelConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this label? This will remove the label from all cards.",
    ),
    "description": MessageLookupByLibrary.simpleMessage("Description"),
    "descriptionOptional": MessageLookupByLibrary.simpleMessage(
      "Description (optional)",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerContent1Desc": MessageLookupByLibrary.simpleMessage(
      "The information provided on this platform is for general informational purposes only. We make no warranties about the completeness, accuracy, or reliability of the content. Any action you take upon the information is strictly at your own risk.",
    ),
    "disclaimerContent1Title": MessageLookupByLibrary.simpleMessage(
      "Content Accuracy",
    ),
    "disclaimerContent2Desc": MessageLookupByLibrary.simpleMessage(
      "This platform may contain links to external websites. We have no control over the content and nature of these sites and are not responsible for any damages from browsing or using them.",
    ),
    "disclaimerContent2Title": MessageLookupByLibrary.simpleMessage(
      "External Links",
    ),
    "disclaimerContent3Desc": MessageLookupByLibrary.simpleMessage(
      "In no event shall we be liable for any direct, indirect, incidental, consequential, or special damages arising out of or in connection with the use of this platform.",
    ),
    "disclaimerContent3Title": MessageLookupByLibrary.simpleMessage(
      "Limitation of Liability",
    ),
    "discover": MessageLookupByLibrary.simpleMessage("Discover"),
    "dueDate": MessageLookupByLibrary.simpleMessage("Due Date"),
    "editCard": MessageLookupByLibrary.simpleMessage("Edit Card"),
    "editDescription": MessageLookupByLibrary.simpleMessage("Edit Description"),
    "errorOccurred": MessageLookupByLibrary.simpleMessage("Error Occurred!"),
    "featureNotAvailable": MessageLookupByLibrary.simpleMessage(
      "This feature is coming soon",
    ),
    "followSystem": MessageLookupByLibrary.simpleMessage("System"),
    "footerText": MessageLookupByLibrary.simpleMessage(
      "© 2026 GoWind Kanban  ·  Powered by Flutter",
    ),
    "guestUser": MessageLookupByLibrary.simpleMessage("Guest"),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "hotSearch": MessageLookupByLibrary.simpleMessage("Hot Searches"),
    "hotTags": MessageLookupByLibrary.simpleMessage("Hot Tags"),
    "labelManagement": MessageLookupByLibrary.simpleMessage("Label Management"),
    "labelName": MessageLookupByLibrary.simpleMessage("Label Name"),
    "labels": MessageLookupByLibrary.simpleMessage("Labels"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "latestPosts": MessageLookupByLibrary.simpleMessage("Latest Posts"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "likes": MessageLookupByLibrary.simpleMessage("Likes"),
    "login": MessageLookupByLibrary.simpleMessage("Login"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Login"),
    "loginFailed": MessageLookupByLibrary.simpleMessage(
      "Login failed, please check username and password",
    ),
    "loginForMore": MessageLookupByLibrary.simpleMessage(
      "Login for more features",
    ),
    "loginSuccess": MessageLookupByLibrary.simpleMessage("Login successful"),
    "logout": MessageLookupByLibrary.simpleMessage("Logout"),
    "logoutConfirm": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to logout?",
    ),
    "manageComments": MessageLookupByLibrary.simpleMessage(
      "Manage your comments",
    ),
    "me": MessageLookupByLibrary.simpleMessage("Me"),
    "monthDay": m3,
    "myBookmarks": MessageLookupByLibrary.simpleMessage("My Bookmarks"),
    "myComments": MessageLookupByLibrary.simpleMessage("My Comments"),
    "newBoard": MessageLookupByLibrary.simpleMessage("New Board"),
    "newCard": MessageLookupByLibrary.simpleMessage("New Card"),
    "newColumn": MessageLookupByLibrary.simpleMessage("New Column"),
    "noBoards": MessageLookupByLibrary.simpleMessage("No boards"),
    "noBookmarks": MessageLookupByLibrary.simpleMessage(
      "No bookmarked articles yet",
    ),
    "noCommentsYet": MessageLookupByLibrary.simpleMessage("No comments yet"),
    "noLabels": MessageLookupByLibrary.simpleMessage("No labels"),
    "noNewMessages": MessageLookupByLibrary.simpleMessage("No new messages"),
    "noRelatedPosts": MessageLookupByLibrary.simpleMessage(
      "No related articles yet",
    ),
    "noSearchResults": m4,
    "notifications": MessageLookupByLibrary.simpleMessage("Notifications"),
    "offline": MessageLookupByLibrary.simpleMessage("Offline"),
    "pageNotFound": MessageLookupByLibrary.simpleMessage("Page Not Found"),
    "pageNotFoundDesc": MessageLookupByLibrary.simpleMessage(
      "Sorry, the page you are looking for does not exist or has been moved.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordHint": MessageLookupByLibrary.simpleMessage("Enter password"),
    "pendingSync": MessageLookupByLibrary.simpleMessage("Pending Sync"),
    "postsCount": m5,
    "postsCountFull": m6,
    "privacyContent1Desc": MessageLookupByLibrary.simpleMessage(
      "We collect minimal personal information necessary to provide our services. This may include your email address, username, and usage preferences. We do not sell or share your personal data with third parties.",
    ),
    "privacyContent1Title": MessageLookupByLibrary.simpleMessage(
      "Information Collection",
    ),
    "privacyContent2Desc": MessageLookupByLibrary.simpleMessage(
      "Your data is stored securely on our servers with industry-standard encryption. We retain your data only for as long as necessary to provide the services or as required by law.",
    ),
    "privacyContent2Title": MessageLookupByLibrary.simpleMessage(
      "Data Storage",
    ),
    "privacyContent3Desc": MessageLookupByLibrary.simpleMessage(
      "We use essential cookies to ensure the proper functioning of the platform. Analytics cookies may be used to improve user experience, which can be disabled in your browser settings.",
    ),
    "privacyContent3Title": MessageLookupByLibrary.simpleMessage(
      "Cookies & Tracking",
    ),
    "privacyContent4Desc": MessageLookupByLibrary.simpleMessage(
      "You have the right to access, correct, or delete your personal data at any time. Contact our support team for any privacy-related requests.",
    ),
    "privacyContent4Title": MessageLookupByLibrary.simpleMessage("Your Rights"),
    "privacyPolicy": MessageLookupByLibrary.simpleMessage("Privacy Policy"),
    "readPosts": MessageLookupByLibrary.simpleMessage("Articles Read"),
    "readingStats": MessageLookupByLibrary.simpleMessage("Reading Stats"),
    "readingTime": MessageLookupByLibrary.simpleMessage("Reading Time"),
    "recommend": MessageLookupByLibrary.simpleMessage("Recommend"),
    "recommendedReading": MessageLookupByLibrary.simpleMessage(
      "Recommended Reading",
    ),
    "relatedArticles": MessageLookupByLibrary.simpleMessage("Related Articles"),
    "relatedPostsCount": m7,
    "relatedPostsCountFull": m8,
    "relatedTags": MessageLookupByLibrary.simpleMessage("Related Tags"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "renameBoard": MessageLookupByLibrary.simpleMessage("Rename Board"),
    "renameColumn": MessageLookupByLibrary.simpleMessage("Rename Column"),
    "reply": MessageLookupByLibrary.simpleMessage("Reply"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "searchHint": MessageLookupByLibrary.simpleMessage(
      "Search articles, tags...",
    ),
    "selectDate": MessageLookupByLibrary.simpleMessage("Select Date"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "share": MessageLookupByLibrary.simpleMessage("Share"),
    "targetColumn": MessageLookupByLibrary.simpleMessage("Target Column"),
    "tenantCode": MessageLookupByLibrary.simpleMessage("Tenant Code"),
    "tenantCodeHint": MessageLookupByLibrary.simpleMessage("Enter tenant code"),
    "termsContent1Desc": MessageLookupByLibrary.simpleMessage(
      "By accessing and using this platform, you agree to be bound by these Terms of Service. If you do not agree with any part of these terms, you must not use the platform.",
    ),
    "termsContent1Title": MessageLookupByLibrary.simpleMessage(
      "Acceptance of Terms",
    ),
    "termsContent2Desc": MessageLookupByLibrary.simpleMessage(
      "You are responsible for maintaining the confidentiality of your account. You agree not to post any content that is unlawful, harmful, threatening, abusive, or otherwise objectionable.",
    ),
    "termsContent2Title": MessageLookupByLibrary.simpleMessage(
      "User Responsibilities",
    ),
    "termsContent3Desc": MessageLookupByLibrary.simpleMessage(
      "Users must not attempt to gain unauthorized access to our systems, interfere with the platform\'s operation, or use automated tools to scrape or collect data without permission.",
    ),
    "termsContent3Title": MessageLookupByLibrary.simpleMessage(
      "Prohibited Activities",
    ),
    "termsContent4Desc": MessageLookupByLibrary.simpleMessage(
      "We reserve the right to modify these terms at any time. Continued use of the platform after changes constitutes acceptance of the updated terms.",
    ),
    "termsContent4Title": MessageLookupByLibrary.simpleMessage("Modifications"),
    "termsOfService": MessageLookupByLibrary.simpleMessage("Terms of Service"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme Color"),
    "themeLanguagePrefs": MessageLookupByLibrary.simpleMessage(
      "Theme, language & preferences",
    ),
    "today": MessageLookupByLibrary.simpleMessage("Today"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Update Failed"),
    "userID": MessageLookupByLibrary.simpleMessage("User ID"),
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "usernameHint": MessageLookupByLibrary.simpleMessage("Enter username"),
    "versionInfo": MessageLookupByLibrary.simpleMessage("Version info & help"),
    "viewReadingHistory": MessageLookupByLibrary.simpleMessage(
      "View reading history",
    ),
    "views": MessageLookupByLibrary.simpleMessage("Views"),
    "weeksAgo": m9,
    "welcomeBack": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "writeComment": MessageLookupByLibrary.simpleMessage(
      "Write your comment...",
    ),
    "yearMonthDay": m10,
    "yesterday": MessageLookupByLibrary.simpleMessage("Yesterday"),
  };
}
