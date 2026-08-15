import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around the FastAPI backend. Point [baseUrl] at your
/// deployed API per environment via --dart-define=API_BASE_URL=...
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://acd-man.onrender.com',
  );

  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode != 200) {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey('detail')) {
            throw Exception(body['detail']);
          }
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        }
        throw Exception('Login failed: ${res.body}');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      if (e is Exception && (e.toString().contains('SocketException') || e.toString().contains('SocketFailed') || e.toString().contains('ClientException'))) {
        throw Exception('Cannot connect to server ($baseUrl). Please check internet connection.');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getAcademies() async {
    final res = await http.get(Uri.parse('$baseUrl/academies'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load academies: ${res.body}');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAcademy(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/academies/$id'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load academy: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<StudentSummary>> getStudents() async {
    final res = await http.get(Uri.parse('$baseUrl/students'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load students: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => StudentSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createStudent({
    required String name,
    String? dateOfBirth,
    String? batchId,
    String? level,
    String? parentName,
    String? parentPhone,
    String? parentEmail,
    String? parentAddress,
    int? defaultFee,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/students'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'date_of_birth': dateOfBirth,
        'batch_id': batchId,
        'level': level,
        'parent_name': parentName,
        'parent_phone': parentPhone,
        'parent_email': parentEmail,
        'parent_address': parentAddress,
        'default_fee': defaultFee,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create student: ${res.body}');
    }
  }

  Future<void> updateStudent(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/students/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update student: ${res.body}');
    }
  }

  Future<void> deleteStudent(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/students/$id'), headers: _headers);
    if (res.statusCode != 204) throw Exception('Failed to delete student: ${res.body}');
  }

  Future<void> hardDeleteStudent(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/students/$id/permanent'), headers: _headers);
    if (res.statusCode != 204) throw Exception('Failed to permanently delete student: ${res.body}');
  }

  Future<List<BatchSummary>> getBatches() async {
    final res = await http.get(Uri.parse('$baseUrl/batches'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load batches: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => BatchSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createBatch({
    required String name,
    String? level,
    String? scheduleDays,
    String? startTime,
    String? endTime,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/batches'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'level': level,
        'schedule_days': scheduleDays,
        'start_time': startTime,
        'end_time': endTime,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create batch: ${res.body}');
    }
  }

  Future<List<PaymentSummary>> getPayments() async {
    final res = await http.get(Uri.parse('$baseUrl/payments'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load fees: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => PaymentSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPayment({
    required String studentId,
    required String planType,
    required int amount,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: _headers,
      body: jsonEncode({'student_id': studentId, 'plan_type': planType, 'amount': amount}),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create fee: ${res.body}');
    }
  }

  /// [status] is "unpaid" / "partial" / "paid". [amountPaid] only
  /// matters for "partial" - the backend fills it in automatically for
  /// the other two (0 for unpaid, the full amount for paid).
  Future<void> updatePaymentStatus(String paymentId, String status, {int? amountPaid}) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/payments/$paymentId/status'),
      headers: _headers,
      body: jsonEncode({'status': status, if (amountPaid != null) 'amount_paid': amountPaid}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update payment status: ${res.body}');
    }
  }

  Future<void> sendPaymentEmail(String paymentId, {String? targetEmail}) async {
    final uri = Uri.parse('$baseUrl/payments/$paymentId/send-email').replace(
      queryParameters: targetEmail != null && targetEmail.isNotEmpty ? {'target_email': targetEmail} : null,
    );
    final res = await http.post(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to send invoice email: ${res.body}');
    }
  }

  /// Sends a custom WhatsApp broadcast. Pass either [studentIds] for
  /// specific students, or [sendToAll]=true for everyone in the academy.
  Future<void> sendBroadcast({
    required String body,
    List<String>? studentIds,
    bool sendToAll = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/messages/broadcast'),
      headers: _headers,
      body: jsonEncode({
        'message_type': 'custom',
        'body': body,
        'student_ids': studentIds,
        'send_to_all': sendToAll,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to send message: ${res.body}');
    }
  }

  Future<List<CalendarDay>> getCalendar(int year, int month) async {
    final res = await http.get(
      Uri.parse('$baseUrl/calendar?year=$year&month=$month'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load calendar: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => CalendarDay.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DayAttendance> getDayAttendance(String date) async {
    final res = await http.get(
      Uri.parse('$baseUrl/attendance/day?date=$date'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load attendance: ${res.body}');
    }
    return DayAttendance.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> markAttendance({
    required String batchId,
    required String date,
    required String studentId,
    required String status,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/attendance/mark'),
      headers: _headers,
      body: jsonEncode({
        'batch_id': batchId,
        'date': date,
        'student_id': studentId,
        'status': status,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark attendance: ${res.body}');
    }
  }

  Future<void> markHoliday(String date, {String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/holidays'),
      headers: _headers,
      body: jsonEncode({'date': date, 'reason': reason}),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to mark holiday: ${res.body}');
    }
  }

  Future<StudentAttendanceSummary> getStudentAttendance(
    String studentId,
    int year,
    int month,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/students/$studentId/attendance?year=$year&month=$month'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load student attendance: ${res.body}');
    }
    return StudentAttendanceSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ---- Academy Management ----

  Future<DashboardStats> getDashboardStats() async {
    final res = await http.get(Uri.parse('$baseUrl/dashboard-stats'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load dashboard stats: ${res.body}');
    return DashboardStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createAcademy(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/academies'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 201) throw Exception('Failed to create academy: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> resetAcademyPassword(String academyId, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/academies/$academyId/reset-password'),
      headers: _headers,
      body: jsonEncode({'new_password': newPassword}),
    );
    if (res.statusCode != 200) throw Exception('Failed to reset password: ${res.body}');
  }

  Future<void> updateAcademy(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Failed to update academy: ${res.body}');
  }

  Future<void> suspendAcademy(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/academies/$id/suspend'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to suspend academy: ${res.body}');
  }

  Future<void> activateAcademy(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/academies/$id/activate'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to activate academy: ${res.body}');
  }

  Future<void> deleteAcademy(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/academies/$id'), headers: _headers);
    if (res.statusCode != 204) throw Exception('Failed to delete academy: ${res.body}');
  }

  Future<void> uploadLogo(String academyId, List<int> bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/academies/$academyId/logo'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await request.send();
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw Exception('Failed to upload logo: $body');
    }
  }

  Future<void> deleteLogo(String academyId) async {
    final res = await http.delete(Uri.parse('$baseUrl/academies/$academyId/logo'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to delete logo: ${res.body}');
    }
  }

  // ---- Users ----

  Future<List<UserSummary>> getUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/users'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load users: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/users/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Failed to update user: ${res.body}');
  }

  Future<void> enableUser(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/users/$id/enable'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to enable user: ${res.body}');
  }

  Future<void> disableUser(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/users/$id/disable'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to disable user: ${res.body}');
  }

  Future<void> deleteUser(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/$id'), headers: _headers);
    if (res.statusCode != 204) throw Exception('Failed to delete user: ${res.body}');
  }

  // ---- Audit Logs ----

  Future<List<AuditLogSummary>> getAuditLogs() async {
    final res = await http.get(Uri.parse('$baseUrl/audit-logs'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load audit logs: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AuditLogSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Platform Billing ----

  Future<List<PlatformInvoiceSummary>> getPlatformInvoices() async {
    final res = await http.get(Uri.parse('$baseUrl/platform-billing'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load invoices: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => PlatformInvoiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPlatformInvoice(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/platform-billing'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 201) throw Exception('Failed to create invoice: ${res.body}');
  }

  Future<void> updatePlatformInvoiceStatus(String id, String status) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/platform-billing/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) throw Exception('Failed to update status: ${res.body}');
  }

  Future<void> notifyPlatformInvoice(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/platform-billing/$id/notify'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to send notification: ${res.body}');
  }

  // ---- Notifications ----

  Future<List<NotificationSummary>> getNotifications() async {
    final res = await http.get(Uri.parse('$baseUrl/notifications'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load notifications: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => NotificationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/notifications/$id/read'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to mark read: ${res.body}');
  }

  // ---- Expenses ----

  Future<List<ExpenseSummary>> getExpenses() async {
    final res = await http.get(Uri.parse('$baseUrl/expenses'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load expenses: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => ExpenseSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addExpense(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) throw Exception('Failed to add expense: ${res.body}');
  }

  // ---- Batch Updates ----

  Future<void> updateBatch(String id, Map<String, dynamic> payload) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/batches/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) throw Exception('Failed to update batch: ${res.body}');
  }

  // ---- Tournaments ----

  Future<List<TournamentSummary>> getTournaments() async {
    final res = await http.get(Uri.parse('$baseUrl/tournaments'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load tournaments: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => TournamentSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createTournament(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tournaments'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) throw Exception('Failed to create tournament: ${res.body}');
  }

  Future<void> registerForTournament(String tournamentId, String studentId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tournaments/$tournamentId/register'),
      headers: _headers,
      body: jsonEncode({'student_id': studentId}),
    );
    if (res.statusCode != 201) throw Exception('Failed to register for tournament: ${res.body}');
  }

  Future<Map<String, dynamic>> getPublicTournament(String tournamentId) async {
    final res = await http.get(Uri.parse('$baseUrl/tournaments/public/$tournamentId'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load tournament: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRazorpayOrder(String tournamentId, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tournaments/public/$tournamentId/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create Razorpay order: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyTournamentPayment(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tournaments/public/verify-payment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw Exception('Payment verification failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTournamentRegistrations(String tournamentId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/tournaments/$tournamentId/registrations'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load roster: ${res.body}');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ---- Materials ----

  Future<List<MaterialSummary>> getMaterials() async {
    final res = await http.get(Uri.parse('$baseUrl/materials'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load materials: ${res.body}');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => MaterialSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createMaterial(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/materials'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode != 201) throw Exception('Failed to add material: ${res.body}');
  }

  Future<void> sellMaterial(String materialId, String? studentId, int quantity) async {
    final res = await http.post(
      Uri.parse('$baseUrl/materials/sell'),
      headers: _headers,
      body: jsonEncode({
        'material_id': materialId,
        'student_id': studentId,
        'quantity': quantity,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to sell material: ${res.body}');
  }

  // ---- Reports ----

  Future<ReportSummaryData> getReportSummary() async {
    final res = await http.get(Uri.parse('$baseUrl/reports/summary'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load report summary: ${res.body}');
    return ReportSummaryData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class TournamentSummary {
  final String id;
  final String name;
  final String? organizerName;
  final String? organizerPhone;
  final String? organizerEmail;
  final String tournamentType;
  final String sports;
  final String category;
  final String status;
  final String? startDate;
  final String? endDate;
  final String? reportingTime;
  final String? venue;
  final String? cityOrPlace;
  final int? feeAmount;
  final String? notes;
  final String? rulesAndPrizes;
  final String? resultUrl;
  final String? bannerUrl;
  final String? brochureUrl;
  final int participantCount;
  final int totalCollected;

  TournamentSummary({
    required this.id,
    required this.name,
    this.organizerName,
    this.organizerPhone,
    this.organizerEmail,
    required this.tournamentType,
    required this.sports,
    required this.category,
    required this.status,
    this.startDate,
    this.endDate,
    this.reportingTime,
    this.venue,
    this.cityOrPlace,
    this.feeAmount,
    this.notes,
    this.rulesAndPrizes,
    this.resultUrl,
    this.bannerUrl,
    this.brochureUrl,
    required this.participantCount,
    required this.totalCollected,
  });

  factory TournamentSummary.fromJson(Map<String, dynamic> json) {
    return TournamentSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      organizerName: json['organizer_name'] as String?,
      organizerPhone: json['organizer_phone'] as String?,
      organizerEmail: json['organizer_email'] as String?,
      tournamentType: json['tournament_type'] as String? ?? 'in_house',
      sports: json['sports'] as String? ?? 'Chess',
      category: json['category'] as String? ?? 'Open',
      status: json['status'] as String? ?? 'open',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      reportingTime: json['reporting_time'] as String?,
      venue: json['venue'] as String?,
      cityOrPlace: json['city_or_place'] as String?,
      feeAmount: json['fee_amount'] as int?,
      notes: json['notes'] as String?,
      rulesAndPrizes: json['rules_and_prizes'] as String?,
      resultUrl: json['result_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      brochureUrl: json['brochure_url'] as String?,
      participantCount: json['participant_count'] as int? ?? 0,
      totalCollected: json['total_collected'] as int? ?? 0,
    );
  }
}

class MaterialSummary {
  final String id;
  final String name;
  final String? description;
  final int price;
  final int stockQuantity;

  MaterialSummary({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stockQuantity,
  });

  factory MaterialSummary.fromJson(Map<String, dynamic> json) {
    return MaterialSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: json['price'] as int,
      stockQuantity: json['stock_quantity'] as int,
    );
  }
}

class ReportSummaryData {
  final int totalStudents;
  final int totalRevenue;
  final int totalExpenses;
  final int netProfit;
  final double averageAttendancePercentage;

  ReportSummaryData({
    required this.totalStudents,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.averageAttendancePercentage,
  });

  factory ReportSummaryData.fromJson(Map<String, dynamic> json) {
    return ReportSummaryData(
      totalStudents: json['total_students'] as int,
      totalRevenue: json['total_revenue'] as int,
      totalExpenses: json['total_expenses'] as int,
      netProfit: json['net_profit'] as int,
      averageAttendancePercentage: (json['average_attendance_percentage'] as num).toDouble(),
    );
  }
}
class StudentSummary {
  final String id;
  final String name;
  final String? dateOfBirth;
  final String? level;
  final String? batchId;
  final String? batchName;
  final int? defaultFee;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final String? parentAddress;

  StudentSummary({
    required this.id,
    required this.name,
    this.dateOfBirth,
    this.level,
    this.batchId,
    this.batchName,
    this.defaultFee,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    this.parentAddress,
  });

  int? get age {
    if (dateOfBirth == null || dateOfBirth!.isEmpty) return null;
    try {
      final dob = DateTime.parse(dateOfBirth!);
      final today = DateTime.now();
      int yrs = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        yrs--;
      }
      return yrs >= 0 ? yrs : null;
    } catch (_) {
      return null;
    }
  }

  String get formattedDobAndAge {
    if (dateOfBirth == null || dateOfBirth!.isEmpty) return 'DOB: Not set';
    try {
      final dob = DateTime.parse(dateOfBirth!);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formatted = '${dob.day.toString().padLeft(2, '0')} ${months[dob.month - 1]} ${dob.year}';
      final calcAge = age;
      return calcAge != null ? '$formatted ($calcAge yrs)' : formatted;
    } catch (_) {
      return 'DOB: $dateOfBirth';
    }
  }

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      dateOfBirth: json['date_of_birth'] as String?,
      level: json['level'] as String?,
      batchId: json['batch_id'] as String?,
      batchName: json['batch_name'] as String?,
      defaultFee: json['default_fee'] as int?,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      parentEmail: json['parent_email'] as String?,
      parentAddress: json['parent_address'] as String?,
    );
  }
}

class CalendarDay {
  final String date;
  final int studentsPresent;
  final int studentsAbsent;
  final int studentsUnmarked;
  final bool isHoliday;

  CalendarDay({
    required this.date,
    required this.studentsPresent,
    required this.studentsAbsent,
    required this.studentsUnmarked,
    required this.isHoliday,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: json['date'] as String,
      studentsPresent: json['students_present'] as int? ?? 0,
      studentsAbsent: json['students_absent'] as int? ?? 0,
      studentsUnmarked: json['students_unmarked'] as int? ?? 0,
      isHoliday: json['is_holiday'] as bool? ?? false,
    );
  }
}

class StudentMark {
  final String studentId;
  final String name;
  final String status; // present / absent / unmarked

  StudentMark({required this.studentId, required this.name, required this.status});

  factory StudentMark.fromJson(Map<String, dynamic> json) {
    return StudentMark(
      studentId: json['student_id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
    );
  }
}

class BatchAttendance {
  final String batchId;
  final String batchName;
  final List<StudentMark> students;

  BatchAttendance({required this.batchId, required this.batchName, required this.students});

  factory BatchAttendance.fromJson(Map<String, dynamic> json) {
    return BatchAttendance(
      batchId: json['batch_id'] as String,
      batchName: json['batch_name'] as String,
      students: (json['students'] as List<dynamic>)
          .map((s) => StudentMark.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DayAttendance {
  final String date;
  final bool isHoliday;
  final List<BatchAttendance> batches;

  DayAttendance({required this.date, required this.isHoliday, required this.batches});

  factory DayAttendance.fromJson(Map<String, dynamic> json) {
    return DayAttendance(
      date: json['date'] as String,
      isHoliday: json['is_holiday'] as bool,
      batches: (json['batches'] as List<dynamic>)
          .map((b) => BatchAttendance.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StudentAttendanceSummary {
  final int daysPresent;
  final int daysAbsent;
  final int totalMarked;

  StudentAttendanceSummary({
    required this.daysPresent,
    required this.daysAbsent,
    required this.totalMarked,
  });

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceSummary(
      daysPresent: json['days_present'] as int,
      daysAbsent: json['days_absent'] as int,
      totalMarked: json['total_marked'] as int,
    );
  }
}

class BatchSummary {
  final String id;
  final String name;
  final String? level;
  final String? startTime;
  final String? endTime;
  final String? scheduleDays;
  final int studentCount;

  BatchSummary({
    required this.id,
    required this.name,
    this.level,
    this.startTime,
    this.endTime,
    this.scheduleDays,
    this.studentCount = 0,
  });

  factory BatchSummary.fromJson(Map<String, dynamic> json) {
    return BatchSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      scheduleDays: json['schedule_days'] as String?,
      studentCount: json['student_count'] as int? ?? 0,
    );
  }
}

class PaymentSummary {
  final String id;
  final String? studentId;
  final String? studentName;
  final String planType;
  final int amount;
  final int amountPaid;
  final String status; // unpaid / partial / paid
  final String? dueDate;

  PaymentSummary({
    required this.id,
    this.studentId,
    this.studentName,
    required this.planType,
    required this.amount,
    required this.amountPaid,
    required this.status,
    this.dueDate,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id'] as String,
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String?,
      planType: json['plan_type'] as String,
      amount: json['amount'] as int,
      amountPaid: json['amount_paid'] as int? ?? 0,
      status: json['status'] as String,
      dueDate: json['due_date'] as String?,
    );
  }
}

class PlatformInvoiceSummary {
  final String id;
  final String academyId;
  final String? academyName;
  final int amount;
  final String status;
  final String createdAt;
  final String? clearedAt;

  PlatformInvoiceSummary({
    required this.id,
    required this.academyId,
    this.academyName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.clearedAt,
  });

  factory PlatformInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return PlatformInvoiceSummary(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      academyName: json['academy_name'] as String?,
      amount: json['amount'] as int,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      clearedAt: json['cleared_at'] as String?,
    );
  }
}

class NotificationSummary {
  final String id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final String createdAt;

  NotificationSummary({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool,
      createdAt: json['created_at'] as String,
    );
  }
}

class UserSummary {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? academyId;
  final bool isActive;

  UserSummary({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.academyId,
    required this.isActive,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      academyId: json['academy_id'] as String?,
      isActive: json['is_active'] as bool,
    );
  }
}

class AuditLogSummary {
  final String id;
  final String entityType;
  final String entityId;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final String changedBy;
  final String? changedByName;
  final String changedAt;

  AuditLogSummary({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    this.oldValue,
    this.newValue,
    required this.changedBy,
    this.changedByName,
    required this.changedAt,
  });

  factory AuditLogSummary.fromJson(Map<String, dynamic> json) {
    return AuditLogSummary(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      fieldName: json['field_name'] as String,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      changedBy: json['changed_by'] as String,
      changedByName: json['changed_by_name'] as String?,
      changedAt: json['changed_at'] as String,
    );
  }
}

class DashboardStats {
  final String currentDate;
  final int totalStudents;
  final int totalBatches;
  final int upcomingBatchesToday;
  final int totalIncome;
  final int outstandingDues;
  final String academyName;
  final String academyAddress;
  final String academyPhone;
  final String academyEmail;
  final String? academyLogoUrl;
  final List<dynamic> todaysClasses;
  final List<dynamic> recentTransactions;

  DashboardStats({
    required this.currentDate,
    required this.totalStudents,
    required this.totalBatches,
    required this.upcomingBatchesToday,
    required this.totalIncome,
    required this.outstandingDues,
    required this.academyName,
    required this.academyAddress,
    required this.academyPhone,
    required this.academyEmail,
    this.academyLogoUrl,
    required this.todaysClasses,
    required this.recentTransactions,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      currentDate: json['current_date'] as String,
      totalStudents: json['total_students'] as int,
      totalBatches: json['total_batches'] as int,
      upcomingBatchesToday: json['upcoming_batches_today'] as int,
      totalIncome: json['total_income'] as int,
      outstandingDues: json['outstanding_dues'] as int? ?? 0,
      academyName: json['academy_name'] as String? ?? 'Academy',
      academyAddress: json['academy_address'] as String? ?? '',
      academyPhone: json['academy_phone'] as String? ?? '',
      academyEmail: json['academy_email'] as String? ?? '',
      academyLogoUrl: json['academy_logo_url'] as String?,
      todaysClasses: json['todays_classes'] as List<dynamic>? ?? [],
      recentTransactions: json['recent_transactions'] as List<dynamic>? ?? [],
    );
  }
}

class ExpenseSummary {
  final String id;
  final int amount;
  final String description;
  final String expenseType;
  final String expenseDate;

  ExpenseSummary({
    required this.id,
    required this.amount,
    required this.description,
    required this.expenseType,
    required this.expenseDate,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      id: json['id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      expenseType: json['expense_type'] as String,
      expenseDate: json['expense_date'] as String,
    );
  }
}

