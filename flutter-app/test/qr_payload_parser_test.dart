import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/core/utils/qr_payload_parser.dart';

void main() {
  group('QRPayloadParser Tests', () {
    test('Parses Srishti 2.7 Compact Pipe Format', () {
      final parsed = QRPayloadParser.parse('SR27|A8F29KX4');
      expect(parsed.isSrishtiQR, isTrue);
      expect(parsed.primaryId, equals('A8F29KX4'));
      expect(parsed.candidateKeys, contains('A8F29KX4'));
      expect(parsed.candidateKeys, contains('SR27-A8F29KX4'));
    });

    test('Parses Numeric Registration Pipe Format', () {
      final parsed = QRPayloadParser.parse('SR27|001');
      expect(parsed.isSrishtiQR, isTrue);
      expect(parsed.primaryId, equals('001'));
      expect(parsed.candidateKeys, contains('001'));
      expect(parsed.candidateKeys, contains('SR27-001'));
      expect(parsed.candidateKeys, contains('SRI27-001'));
      expect(parsed.candidateKeys, contains('TEST-SRI27-001'));
    });

    test('Parses Srishti 2.7 JSON QR Format', () {
      const jsonStr = '{"v":1,"event":"SRISHTI27","id":"A8F29KX4"}';
      final parsed = QRPayloadParser.parse(jsonStr);
      expect(parsed.isSrishtiQR, isTrue);
      expect(parsed.primaryId, equals('A8F29KX4'));
      expect(parsed.candidateKeys, contains('A8F29KX4'));
      expect(parsed.candidateKeys, contains('SR27-A8F29KX4'));
    });

    test('Parses Hyphenated Token Format', () {
      final parsed = QRPayloadParser.parse('SR27-A8F29KX4');
      expect(parsed.isSrishtiQR, isTrue);
      expect(parsed.primaryId, equals('A8F29KX4'));
      expect(parsed.candidateKeys, contains('SR27-A8F29KX4'));
      expect(parsed.candidateKeys, contains('A8F29KX4'));
    });

    test('Parses Legacy Test Data Participant Code', () {
      final parsed = QRPayloadParser.parse('TEST-SRI27-001');
      expect(parsed.isSrishtiQR, isTrue);
      expect(parsed.primaryId, equals('001'));
      expect(parsed.candidateKeys, contains('TEST-SRI27-001'));
      expect(parsed.candidateKeys, contains('001'));
    });

    test('Handles raw UUID seamlessly', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final parsed = QRPayloadParser.parse(uuid);
      expect(parsed.isUuid, isTrue);
      expect(parsed.primaryId, equals(uuid));
      expect(parsed.candidateKeys, contains(uuid));
    });
  });
}
