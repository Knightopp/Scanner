import '../../../core/services/supabase_service.dart';
import '../../../core/utils/qr_payload_parser.dart';

/// Service handling participant lookup and verification against the Supabase `participants` table.
///
/// Designed for seamless integration with Srishti 2.7 QR scanner (compact pipe format,
/// JSON payloads, and legacy participant codes) and manual lookup modules.
class ParticipantService {
  final SupabaseService _supabaseService;

  ParticipantService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  /// Looks up a participant by their unique [participantCode] (scanned from QR code or typed).
  ///
  /// Intelligently decodes:
  /// - Srishti 2.7 Standard Pipe QR: "SR27|A8F29KX4" -> matches "A8F29KX4" or "SR27-A8F29KX4"
  /// - Srishti 2.7 JSON QR: {"v":1,"event":"SRISHTI27","id":"A8F29KX4"}
  /// - Direct Tokens: "SR27-A8F29KX4", "SRI27-0001", "TEST-SRI27-001"
  /// - Direct UUIDs
  Future<Map<String, dynamic>?> getParticipantByCode(String participantCode) async {
    final clean = participantCode.trim();
    if (clean.isEmpty) return null;

    final parsed = QRPayloadParser.parse(clean);

    // 1. Direct query checking all prioritized candidate codes
    for (final candidate in parsed.candidateKeys) {
      try {
        final response = await _supabaseService.client
            .from('participants')
            .select()
            .eq('participant_code', candidate.toUpperCase())
            .maybeSingle();

        if (response != null && response.isNotEmpty) {
          return response;
        }
      } catch (_) {
        // Continue to next candidate
      }
    }

    // 2. Direct UUID lookup if the scanned code or extracted ID is a UUID
    if (parsed.isUuid) {
      try {
        final response = await _supabaseService.client
            .from('participants')
            .select()
            .eq('id', parsed.primaryId)
            .maybeSingle();

        if (response != null && response.isNotEmpty) {
          return response;
        }
      } catch (_) {}
    }

    // 3. Fallback fuzzy search by ilike on participant_code
    if (parsed.primaryId.length >= 3) {
      try {
        final response = await _supabaseService.client
            .from('participants')
            .select()
            .ilike('participant_code', '%${parsed.primaryId}%')
            .limit(1)
            .maybeSingle();

        if (response != null && response.isNotEmpty) {
          return response;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Searches participants by name, code, or phone number.
  Future<List<Map<String, dynamic>>> searchParticipants(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Also parse query to extract primary ID if user pastes a QR string into search box
    final parsed = QRPayloadParser.parse(cleanQuery);
    final searchKey = parsed.primaryId.isNotEmpty ? parsed.primaryId : cleanQuery;

    final response = await _supabaseService.client
        .from('participants')
        .select()
        .or('participant_code.ilike.%$searchKey%,name.ilike.%$cleanQuery%,phone.ilike.%$cleanQuery%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }
}
