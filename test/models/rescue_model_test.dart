import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/core/models/rescue_model.dart';

void main() {
  group('RescueModel Tests', () {
    test('should create rescue model with all required fields', () {
      // Arrange
      const id = '1234';
      const description = '测试救援';
      const location = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);
      const altitude = 1970.2;
      final createdAt = DateTime.now();
      const createdBy = 'user_123';

      // Act
      final rescue = RescueModel(
        id: id,
        description: description,
        location: location,
        altitude: altitude,
        createdAt: createdAt,
        createdBy: createdBy,
      );

      // Assert
      expect(rescue.id, equals(id));
      expect(rescue.description, equals(description));
      expect(rescue.location, equals(location));
      expect(rescue.altitude, equals(altitude));
      expect(rescue.createdAt, equals(createdAt));
      expect(rescue.createdBy, equals(createdBy));
      expect(rescue.isActive, isTrue); // 默认值
    });

    test('should create rescue model from JSON', () {
      // Arrange
      final json = {
        'id': '1234',
        'description': '测试救援',
        'location': {
          'latitude': 25.59462,
          'longitude': 100.2457983,
        },
        'altitude': 1970.2,
        'createdAt': '2023-08-13T03:44:19.507981',
        'createdBy': 'user_123',
        'isActive': true,
      };

      // Act
      final rescue = RescueModel.fromJson(json);

      // Assert
      expect(rescue.id, equals('1234'));
      expect(rescue.description, equals('测试救援'));
      expect(rescue.location.latitude, equals(25.59462));
      expect(rescue.location.longitude, equals(100.2457983));
      expect(rescue.altitude, equals(1970.2));
      expect(rescue.createdBy, equals('user_123'));
      expect(rescue.isActive, isTrue);
    });

    test('should convert rescue model to JSON', () {
      // Arrange
      final rescue = RescueModel(
        id: '1234',
        description: '测试救援',
        location: const LocationCoordinate(latitude: 25.59462, longitude: 100.2457983),
        altitude: 1970.2,
        createdAt: DateTime.parse('2023-08-13T03:44:19.507981'),
        createdBy: 'user_123',
        isActive: true,
      );

      // Act
      final json = rescue.toJson();

      // Assert
      expect(json['id'], equals('1234'));
      expect(json['description'], equals('测试救援'));
      expect(json['location']['latitude'], equals(25.59462));
      expect(json['location']['longitude'], equals(100.2457983));
      expect(json['altitude'], equals(1970.2));
      expect(json['createdAt'], equals('2023-08-13T03:44:19.507981'));
      expect(json['createdBy'], equals('user_123'));
      expect(json['isActive'], isTrue);
    });

    test('should handle default isActive value in JSON', () {
      // Arrange
      final json = {
        'id': '1234',
        'description': '测试救援',
        'location': {
          'latitude': 25.59462,
          'longitude': 100.2457983,
        },
        'altitude': 1970.2,
        'createdAt': '2023-08-13T03:44:19.507981',
        'createdBy': 'user_123',
        // 没有 isActive 字段
      };

      // Act
      final rescue = RescueModel.fromJson(json);

      // Assert
      expect(rescue.isActive, isTrue); // 应该使用默认值
    });

    test('should create copy with modified values', () {
      // Arrange
      final originalRescue = RescueModel(
        id: '1234',
        description: '原始描述',
        location: const LocationCoordinate(latitude: 25.59462, longitude: 100.2457983),
        altitude: 1970.2,
        createdAt: DateTime.now(),
        createdBy: 'user_123',
        isActive: true,
      );

      // Act
      final modifiedRescue = originalRescue.copyWith(
        description: '修改后的描述',
        isActive: false,
      );

      // Assert
      expect(modifiedRescue.id, equals(originalRescue.id));
      expect(modifiedRescue.description, equals('修改后的描述'));
      expect(modifiedRescue.location, equals(originalRescue.location));
      expect(modifiedRescue.altitude, equals(originalRescue.altitude));
      expect(modifiedRescue.createdAt, equals(originalRescue.createdAt));
      expect(modifiedRescue.createdBy, equals(originalRescue.createdBy));
      expect(modifiedRescue.isActive, isFalse);
    });

    test('should handle equality correctly', () {
      // Arrange
      final rescue1 = RescueModel(
        id: '1234',
        description: '测试救援',
        location: const LocationCoordinate(latitude: 25.59462, longitude: 100.2457983),
        altitude: 1970.2,
        createdAt: DateTime.now(),
        createdBy: 'user_123',
      );

      final rescue2 = RescueModel(
        id: '1234',
        description: '不同描述',
        location: const LocationCoordinate(latitude: 30.0, longitude: 120.0),
        altitude: 2000.0,
        createdAt: DateTime.now(),
        createdBy: 'user_456',
      );

      final rescue3 = RescueModel(
        id: '5678',
        description: '测试救援',
        location: const LocationCoordinate(latitude: 25.59462, longitude: 100.2457983),
        altitude: 1970.2,
        createdAt: DateTime.now(),
        createdBy: 'user_123',
      );

      // Assert
      expect(rescue1, equals(rescue2)); // 相等性基于ID
      expect(rescue1, isNot(equals(rescue3))); // 不同ID应该不相等
      expect(rescue1.hashCode, equals(rescue2.hashCode)); // 相同ID应该有相同的hashCode
    });

    test('should have proper toString representation', () {
      // Arrange
      final rescue = RescueModel(
        id: '1234',
        description: '测试救援',
        location: const LocationCoordinate(latitude: 25.59462, longitude: 100.2457983),
        altitude: 1970.2,
        createdAt: DateTime.parse('2023-08-13T03:44:19.507981'),
        createdBy: 'user_123',
        isActive: true,
      );

      // Act
      final stringRepresentation = rescue.toString();

      // Assert
      expect(stringRepresentation, contains('1234'));
      expect(stringRepresentation, contains('测试救援'));
      expect(stringRepresentation, contains('25.59462'));
      expect(stringRepresentation, contains('100.2457983'));
      expect(stringRepresentation, contains('1970.2'));
      expect(stringRepresentation, contains('user_123'));
      expect(stringRepresentation, contains('true'));
    });
  });

  group('LocationCoordinate Tests', () {
    test('should create location coordinate', () {
      // Arrange & Act
      const location = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);

      // Assert
      expect(location.latitude, equals(25.59462));
      expect(location.longitude, equals(100.2457983));
    });

    test('should create location coordinate from JSON', () {
      // Arrange
      final json = {
        'latitude': 25.59462,
        'longitude': 100.2457983,
      };

      // Act
      final location = LocationCoordinate.fromJson(json);

      // Assert
      expect(location.latitude, equals(25.59462));
      expect(location.longitude, equals(100.2457983));
    });

    test('should convert location coordinate to JSON', () {
      // Arrange
      const location = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);

      // Act
      final json = location.toJson();

      // Assert
      expect(json['latitude'], equals(25.59462));
      expect(json['longitude'], equals(100.2457983));
    });

    test('should create copy with modified values', () {
      // Arrange
      const originalLocation = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);

      // Act
      final modifiedLocation = originalLocation.copyWith(latitude: 30.0);

      // Assert
      expect(modifiedLocation.latitude, equals(30.0));
      expect(modifiedLocation.longitude, equals(100.2457983));
    });

    test('should handle equality correctly', () {
      // Arrange
      const location1 = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);
      const location2 = LocationCoordinate(latitude: 25.59462, longitude: 100.2457983);
      const location3 = LocationCoordinate(latitude: 30.0, longitude: 120.0);

      // Assert
      expect(location1, equals(location2));
      expect(location1, isNot(equals(location3)));
      expect(location1.hashCode, equals(location2.hashCode));
    });
  });
}
