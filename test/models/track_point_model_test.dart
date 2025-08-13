import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/core/models/track_point_model.dart';

void main() {
  group('TrackPointModel Tests', () {
    test('should create track point from double values', () {
      // Arrange
      const latitude = 25.59462;
      const longitude = 100.2457983;
      const altitude = 1970.2;
      const accuracy = 5.0;
      final dateTime = DateTime.now();

      // Act
      final trackPoint = TrackPointModel.fromDouble(
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        accuracy: accuracy,
        dateTime: dateTime,
        marked: true,
      );

      // Assert
      expect(trackPoint.latitudeDouble, closeTo(latitude, 0.0000001));
      expect(trackPoint.longitudeDouble, closeTo(longitude, 0.0000001));
      expect(trackPoint.altitudeDouble, closeTo(altitude, 0.01));
      expect(trackPoint.accuracyDouble, closeTo(accuracy, 0.01));
      expect(trackPoint.marked, isTrue);
      // 时间戳精度可能会有微小差异，使用毫秒级比较
      expect(trackPoint.dateTime.millisecondsSinceEpoch,
          equals(dateTime.millisecondsSinceEpoch));
    });

    test('should create track point from compressed string', () {
      // Arrange
      const compressedString =
          '255946200,1002457983,197020,500,true,1692000000000';

      // Act
      final trackPoint = TrackPointModel.fromCompressedString(compressedString);

      // Assert
      expect(trackPoint.latitude, equals(255946200));
      expect(trackPoint.longitude, equals(1002457983));
      expect(trackPoint.altitude, equals(197020));
      expect(trackPoint.accuracy, equals(500));
      expect(trackPoint.marked, isTrue);
      expect(trackPoint.timestamp, equals(1692000000000));
    });

    test('should convert to compressed string', () {
      // Arrange
      final trackPoint = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000,
        marked: true,
      );

      // Act
      final compressedString = trackPoint.toCompressedString();

      // Assert
      expect(compressedString,
          equals('255946200,1002457983,197020,500,true,1692000000000'));
    });

    test('should create stop marker', () {
      // Act
      final stopMarker = TrackPointModel.createStopMarker();

      // Assert
      expect(stopMarker.latitude, equals(0));
      expect(stopMarker.longitude, equals(0));
      expect(stopMarker.altitude, equals(0));
      expect(stopMarker.accuracy, equals(0));
      expect(stopMarker.marked, isFalse);
      expect(stopMarker.isStopMarker, isTrue);
    });

    test('should convert to and from JSON', () {
      // Arrange
      final originalPoint = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000,
        marked: true,
      );

      // Act
      final json = originalPoint.toJson();
      final reconstructedPoint = TrackPointModel.fromJson(json);

      // Assert
      expect(reconstructedPoint.latitude, equals(originalPoint.latitude));
      expect(reconstructedPoint.longitude, equals(originalPoint.longitude));
      expect(reconstructedPoint.altitude, equals(originalPoint.altitude));
      expect(reconstructedPoint.accuracy, equals(originalPoint.accuracy));
      expect(reconstructedPoint.timestamp, equals(originalPoint.timestamp));
      expect(reconstructedPoint.marked, equals(originalPoint.marked));
    });

    test('should handle precision correctly', () {
      // Arrange
      const latitude = 25.5946234567; // 高精度纬度
      const longitude = 100.2457983456; // 高精度经度

      // Act
      final trackPoint = TrackPointModel.fromDouble(
        latitude: latitude,
        longitude: longitude,
        altitude: 1970.25,
        accuracy: 5.75,
        dateTime: DateTime.now(),
      );

      // Assert
      // 检查精度是否保持在0.1米范围内
      expect((trackPoint.latitudeDouble - latitude).abs(), lessThan(0.0000001));
      expect(
          (trackPoint.longitudeDouble - longitude).abs(), lessThan(0.0000001));
    });

    test('should create copy with modified values', () {
      // Arrange
      final originalPoint = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000,
        marked: false,
      );

      // Act
      final modifiedPoint = originalPoint.copyWith(marked: true);

      // Assert
      expect(modifiedPoint.latitude, equals(originalPoint.latitude));
      expect(modifiedPoint.longitude, equals(originalPoint.longitude));
      expect(modifiedPoint.altitude, equals(originalPoint.altitude));
      expect(modifiedPoint.accuracy, equals(originalPoint.accuracy));
      expect(modifiedPoint.timestamp, equals(originalPoint.timestamp));
      expect(modifiedPoint.marked, isTrue); // 这个值应该被修改
    });

    test('should handle equality correctly', () {
      // Arrange
      final point1 = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000,
        marked: false,
      );

      final point2 = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000000000,
        marked: true, // 不同的marked值
      );

      final point3 = TrackPointModel(
        latitude: 255946200,
        longitude: 1002457983,
        altitude: 197020,
        accuracy: 500,
        timestamp: 1692000001000, // 不同的时间戳
        marked: false,
      );

      // Assert
      expect(point1, equals(point2)); // 相等性基于位置和时间戳
      expect(point1, isNot(equals(point3))); // 不同时间戳应该不相等
    });

    test('should throw error for invalid compressed string', () {
      // Arrange
      const invalidString = '255946200,1002457983,197020'; // 缺少字段

      // Act & Assert
      expect(
        () => TrackPointModel.fromCompressedString(invalidString),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
