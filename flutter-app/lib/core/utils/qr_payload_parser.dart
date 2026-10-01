import 'dart:convert';

/// Represents a parsed QR payload from the Srishti 2.7 QR Generator or legacy registrations.
class ParsedQRPayload {
  final String rawInput;
  final String primaryId;
  final List<String> candidateKeys;
  final String formatName;
  final bool isSrishtiQR;
  final bool isUuid;
  final Map<String, dynamic>? metadata;

  const ParsedQRPayload({
    required this.rawInput,
    required this.primaryId,
    required this.candidateKeys,
    required this.formatName,
    required this.isSrishtiQR,
    required this.isUuid,
    this.metadata,
  });

  @override
  String toString() => 'ParsedQRPayload(id: $primaryId, format: $formatName, candidates: $candidateKeys)';
}

/// Utility for parsing and decoding Srishti 2.7 attendee QR codes.
///
/// Designed to seamlessly decode:
/// 1. Compact Pipe Format: "SR27|A8F29KX4" or "SR27|001" or "SR27|SR27-001"
/// 2. Srishti JSON Format: {"v": 1, "event": "SRISHTI27", "id": "A8F29KX4"}
/// 3. Token Formats: "SR27-A8F29KX4", "SRI27-0001", "TEST-SRI27-001"
/// 4. Direct Participant UUIDs or alphanumeric identifiers
class QRPayloadParser {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Parses any scanned QR code string into a [ParsedQRPayload] with prioritized candidate lookup keys.
  static ParsedQRPayload parse(String rawScanned) {
    final trimmed = rawScanned.trim();
    if (trimmed.isEmpty) {
      return const ParsedQRPayload(
        rawInput: '',
        primaryId: '',
        candidateKeys: [],
        formatName: 'Empty',
        isSrishtiQR: false,
        isUuid: false,
      );
    }

    // 1. UUID Check
    if (_uuidRegex.hasMatch(trimmed)) {
      return ParsedQRPayload(
        rawInput: trimmed,
        primaryId: trimmed.toLowerCase(),
        candidateKeys: [trimmed.toLowerCase()],
        formatName: 'Participant UUID',
        isSrishtiQR: true,
        isUuid: true,
      );
    }

    // 2. JSON Format: {"v":1,"event":"SRISHTI27","id":"A8F29KX4"}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final parsedJson = jsonDecode(trimmed);
        if (parsedJson is Map<String, dynamic>) {
          final id = parsedJson['id']?.toString().trim() ?? '';
          final event = parsedJson['event']?.toString().trim() ?? '';
          final isSrishti = event.toUpperCase().contains('SRISHTI') || event.toUpperCase().contains('SR27');

          if (id.isNotEmpty) {
            final candidates = _generateCandidates(id);
            return ParsedQRPayload(
              rawInput: trimmed,
              primaryId: id,
              candidateKeys: candidates,
              formatName: 'Srishti 2.7 JSON QR',
              isSrishtiQR: isSrishti,
              isUuid: _uuidRegex.hasMatch(id),
              metadata: parsedJson,
            );
          }
        }
      } catch (_) {
        // Fall through if JSON parsing fails
      }
    }

    // 3. Compact Pipe Format: "SR27|A8F29KX4" or "SRISHTI27|A8F29KX4"
    if (trimmed.contains('|')) {
      final parts = trimmed.split('|');
      final prefix = parts[0].trim().toUpperCase();
      final id = parts.sublist(1).join('|').trim();

      final isSrishtiPrefix = prefix == 'SR27' || prefix == 'SRISHTI27' || prefix == 'SRI27';
      final candidates = _generateCandidates(id);

      // Also add exact raw input as low priority candidate
      if (!candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }

      return ParsedQRPayload(
        rawInput: trimmed,
        primaryId: id,
        candidateKeys: candidates,
        formatName: 'Srishti 2.7 Standard QR (Pipe Format)',
        isSrishtiQR: isSrishtiPrefix,
        isUuid: _uuidRegex.hasMatch(id),
        metadata: {'prefix': prefix, 'extractedId': id},
      );
    }

    // 4. Token with Dash: "SR27-A8F29KX4", "TEST-SRI27-001", "SR27-001"
    if (trimmed.contains('-')) {
      final candidates = _generateCandidates(trimmed);
      final isSrishti = trimmed.toUpperCase().startsWith('SR27') ||
          trimmed.toUpperCase().startsWith('SRI27') ||
          trimmed.toUpperCase().startsWith('TEST-SRI27');

      // Extract the suffix ID after the prefix
      String suffix = trimmed;
      if (trimmed.toUpperCase().startsWith('SR27-')) {
        suffix = trimmed.substring(5);
      } else if (trimmed.toUpperCase().startsWith('TEST-SRI27-')) {
        suffix = trimmed.substring(11);
      } else if (trimmed.toUpperCase().startsWith('SRI27-')) {
        suffix = trimmed.substring(6);
      }

      return ParsedQRPayload(
        rawInput: trimmed,
        primaryId: suffix.isNotEmpty ? suffix : trimmed,
        candidateKeys: candidates,
        formatName: 'Srishti 2.7 Token QR',
        isSrishtiQR: isSrishti,
        isUuid: false,
      );
    }

    // 5. Fallback Plain ID: e.g. "A8F29KX4" or "001"
    final candidates = _generateCandidates(trimmed);
    return ParsedQRPayload(
      rawInput: trimmed,
      primaryId: trimmed,
      candidateKeys: candidates,
      formatName: 'Plain Alphanumeric Identifier',
      isSrishtiQR: true,
      isUuid: false,
    );
  }

  /// Generates ordered candidate codes to match against Supabase `participant_code`.
  static List<String> _generateCandidates(String rawId) {
    final clean = rawId.trim();
    final upper = clean.toUpperCase();
    final candidates = <String>{};

    // 1. Direct upper case
    candidates.add(upper);

    // 2. If it has a prefix like SR27-, extract suffix
    String suffix = upper;
    if (upper.startsWith('SR27-')) {
      suffix = upper.replaceFirst('SR27-', '');
      candidates.add(suffix);
    } else if (upper.startsWith('SRI27-')) {
      suffix = upper.replaceFirst('SRI27-', '');
      candidates.add(suffix);
    } else if (upper.startsWith('TEST-SRI27-')) {
      suffix = upper.replaceFirst('TEST-SRI27-', '');
      candidates.add(suffix);
    } else {
      // Add standard prefixed variations
      candidates.add('SR27-$upper');
      candidates.add('SRI27-$upper');
      candidates.add('TEST-SRI27-$upper');
    }

    // 3. Numeric padding variations (e.g. "1" -> "001", "0001", "SR27-001", "SRI27-0001")
    final numVal = int.tryParse(suffix);
    if (numVal != null) {
      final p3 = numVal.toString().padLeft(3, '0');
      final p4 = numVal.toString().padLeft(4, '0');

      candidates.add(p3);
      candidates.add(p4);
      candidates.add('SR27-$p3');
      candidates.add('SR27-$p4');
      candidates.add('SRI27-$p3');
      candidates.add('SRI27-$p4');
      candidates.add('TEST-SRI27-$p3');
    }

    return candidates.toList();
  }
}
