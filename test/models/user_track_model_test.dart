import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/core/models/user_track_model.dart';
import 'package:rescue_app/core/models/track_point_model.dart';

void main() {
  group('UserTrackModel Tests', () {
    late List<TrackPointModel> samplePoints;

    setUp(() {
      samplePoints = [
        TrackPointModel(
          latitude: 255946200,
          longitude: 1002457983,
          altitude: 197020,
          accuracy: 500,
          timestamp: 1692000000000,
          marked: false,
        ),
        TrackPointModel(
          latitude: 255946300,
          longitude: 1002458083,
          altitude: 197030,
          accuracy: 600,
          timestamp: 1692000060000,
          marked: true,
        ),
      ];
    });

    test('should create user track model', () {
      // Arrange & Act
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Assert
      expect(userTrack.userId, equals('user_123'));
      expect(userTrack.points, equals(samplePoints));
      expect(userTrack.index, equals(0));
    });

    test('should create user track from JSON with compressed strings', () {
      // Arrange
      final json = {
        'user_id': 'user_123',
        'points': [
          '255946200,1002457983,197020,500,false,1692000000000',
          '255946300,1002458083,197030,600,true,1692000060000',
        ],
        'index': 0,
      };

      // Act
      final userTrack = UserTrackModel.fromJson(json);

      // Assert
      expect(userTrack.userId, equals('user_123'));
      expect(userTrack.points.length, equals(2));
      expect(userTrack.points[0].latitude, equals(255946200));
      expect(userTrack.points[1].marked, isTrue);
      expect(userTrack.index, equals(0));
    });

    test('should convert user track to JSON with compressed strings', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final json = userTrack.toJson();

      // Assert
      expect(json['user_id'], equals('user_123'));
      expect(json['points'], isA<List<String>>());
      expect(json['points'].length, equals(2));
      expect(json['index'], equals(0));
    });

    test('should generate correct document ID', () {
      // Arrange
      final userTrack1 = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      final userTrack2 = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 1,
      );

      // Act & Assert
      expect(userTrack1.documentId, equals('user-user_123'));
      expect(userTrack2.documentId, equals('user-user_123-1'));
    });

    test('should add points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: [samplePoints[0]],
        index: 0,
      );

      // Act
      final updatedTrack = userTrack.addPoint(samplePoints[1]);

      // Assert
      expect(updatedTrack.points.length, equals(2));
      expect(updatedTrack.points[1], equals(samplePoints[1]));
    });

    test('should add multiple points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: [],
        index: 0,
      );

      // Act
      final updatedTrack = userTrack.addPoints(samplePoints);

      // Assert
      expect(updatedTrack.points.length, equals(2));
      expect(updatedTrack.points, equals(samplePoints));
    });

    test('should remove points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final updatedTrack = userTrack.removePoint(samplePoints[0]);

      // Assert
      expect(updatedTrack.points.length, equals(1));
      expect(updatedTrack.points[0], equals(samplePoints[1]));
    });

    test('should clear points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final clearedTrack = userTrack.clearPoints();

      // Assert
      expect(clearedTrack.points.length, equals(0));
      expect(clearedTrack.isEmpty, isTrue);
    });

    test('should get first and last points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act & Assert
      expect(userTrack.firstPoint, equals(samplePoints[0]));
      expect(userTrack.lastPoint, equals(samplePoints[1]));
    });

    test('should return null for first and last points when empty', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: [],
        index: 0,
      );

      // Act & Assert
      expect(userTrack.firstPoint, isNull);
      expect(userTrack.lastPoint, isNull);
    });

    test('should calculate time range correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final timeRange = userTrack.timeRange;

      // Assert
      expect(timeRange, isNotNull);
      expect(timeRange!.start.millisecondsSinceEpoch, equals(1692000000000));
      expect(timeRange.end.millisecondsSinceEpoch, equals(1692000060000));
      expect(timeRange.duration.inMinutes, equals(1));
    });

    test('should return null time range when empty', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: [],
        index: 0,
      );

      // Act
      final timeRange = userTrack.timeRange;

      // Assert
      expect(timeRange, isNull);
    });

    test('should filter marked and unmarked points correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final markedPoints = userTrack.markedPoints;
      final unmarkedPoints = userTrack.unmarkedPoints;

      // Assert
      expect(markedPoints.length, equals(1));
      expect(markedPoints[0].marked, isTrue);
      expect(unmarkedPoints.length, equals(1));
      expect(unmarkedPoints[0].marked, isFalse);
    });

    test('should estimate size correctly', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final estimatedSize = userTrack.estimatedSizeInBytes;

      // Assert
      expect(estimatedSize, greaterThan(0));
      expect(estimatedSize, lessThan(1000)); // 应该远小于1MB
    });

    test('should detect near size limit correctly', () {
      // Arrange
      // 创建一个大量轨迹点的列表来模拟接近大小限制
      final manyPoints = List.generate(20000, (index) => TrackPointModel(
        latitude: 255946200 + index,
        longitude: 1002457983 + index,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000 + index * 1000,
        marked: false,
      ));

      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: manyPoints,
        index: 0,
      );

      // Act & Assert
      expect(userTrack.isNearSizeLimit, isTrue);
    });

    test('should create copy with modified values', () {
      // Arrange
      final originalTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final modifiedTrack = originalTrack.copyWith(
        userId: 'user_456',
        index: 1,
      );

      // Assert
      expect(modifiedTrack.userId, equals('user_456'));
      expect(modifiedTrack.points, equals(samplePoints));
      expect(modifiedTrack.index, equals(1));
    });

    test('should handle equality correctly', () {
      // Arrange
      final track1 = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      final track2 = UserTrackModel(
        userId: 'user_123',
        points: [], // 不同的points
        index: 0,
      );

      final track3 = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 1, // 不同的index
      );

      // Assert
      expect(track1, equals(track2)); // 相等性基于userId和index
      expect(track1, isNot(equals(track3))); // 不同index应该不相等
    });

    test('should have proper toString representation', () {
      // Arrange
      final userTrack = UserTrackModel(
        userId: 'user_123',
        points: samplePoints,
        index: 0,
      );

      // Act
      final stringRepresentation = userTrack.toString();

      // Assert
      expect(stringRepresentation, contains('user_123'));
      expect(stringRepresentation, contains('2')); // pointCount
      expect(stringRepresentation, contains('0')); // index
    });
  });
}
