part of 'neon_notifications.dart';

class NotificationsAppSpecificOptions extends NextcloudAppSpecificOptions implements NotificationsOptionsInterface {
  NotificationsAppSpecificOptions(super.storage) {
    super.categories = [];
    super.options = [];
  }
}
