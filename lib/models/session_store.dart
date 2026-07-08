import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single completed focus session.
class SessionRecord {
  final DateTime completedAt;

  const SessionRecord({required this.completedAt});

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    completedAt: DateTime.parse(json['completedAt'] as String),
  );
}

/// Persists and queries session history.
class SessionStore {
  static const _kSessions     = 'session_records';
  static const _kCurrentStreak = 'current_streak';
  static const _kLastDate      = 'last_session_date';

  // ── Singleton ──────────────────────────────────────────────────────────
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  List<SessionRecord> _records = [];
  int  _currentStreak = 0;
  DateTime? _lastDate;

  bool _loaded = false;

  // ── Load / Save ───────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getStringList(_kSessions) ?? [];
    _records = raw
        .map((s) => SessionRecord.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();

    _currentStreak = prefs.getInt(_kCurrentStreak) ?? 0;
    final dateStr = prefs.getString(_kLastDate);
    _lastDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

    _pruneOldRecords();
  }

  Future<void> _save(SharedPreferences prefs) async {
    await prefs.setStringList(
      _kSessions,
      _records.map((r) => jsonEncode(r.toJson())).toList(),
    );
    await prefs.setInt(_kCurrentStreak, _currentStreak);
    if (_lastDate != null) {
      await prefs.setString(_kLastDate, _lastDate!.toIso8601String());
    }
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Record a completed session and update streak.
  Future<void> recordSession() async {
    await load();
    final now = DateTime.now();
    _records.add(SessionRecord(completedAt: now));
    _updateStreak(now);
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs);
  }

  /// Number of sessions completed today.
  int get todayCount {
    final today = _today();
    return _records.where((r) => _sameDay(r.completedAt, today)).length;
  }

  /// Total sessions ever recorded.
  int get totalCount => _records.length;

  /// Current daily streak (days in a row with ≥1 session).
  int get currentStreak => _currentStreak;

  // ── Internals ─────────────────────────────────────────────────────────

  void _updateStreak(DateTime now) {
    final today = _today();
    if (_lastDate == null) {
      _currentStreak = 1;
    } else {
      final lastDay = DateTime(_lastDate!.year, _lastDate!.month, _lastDate!.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 0) {
        // Same day — streak unchanged (already incremented by earlier session today)
      } else if (diff == 1) {
        _currentStreak += 1; // consecutive day
      } else {
        _currentStreak = 1; // streak broken
      }
    }
    _lastDate = now;
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Keep only last 90 days to bound storage.
  void _pruneOldRecords() {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _records.removeWhere((r) => r.completedAt.isBefore(cutoff));
  }
}
