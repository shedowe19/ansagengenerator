import 'package:ansagengenerator/core/announcement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dispatch and passing are station-independent platform announcements',
    () {
      expect(AnnouncementMode.dispatch.requiresTrainDetails, isFalse);
      expect(AnnouncementMode.passing.requiresTrainDetails, isFalse);
    },
  );

  test('train announcement modes retain their train detail fields', () {
    expect(AnnouncementMode.entry.requiresTrainDetails, isTrue);
    expect(AnnouncementMode.arrival.requiresTrainDetails, isTrue);
    expect(AnnouncementMode.standing.requiresTrainDetails, isTrue);
    expect(AnnouncementMode.information.requiresTrainDetails, isTrue);
    expect(AnnouncementMode.connection.requiresTrainDetails, isTrue);
  });
}
