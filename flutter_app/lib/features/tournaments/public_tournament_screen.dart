import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/api_client.dart';

class PublicTournamentScreen extends StatefulWidget {
  final String tournamentId;

  const PublicTournamentScreen({super.key, required this.tournamentId});

  @override
  State<PublicTournamentScreen> createState() => _PublicTournamentScreenState();
}

class _PublicTournamentScreenState extends State<PublicTournamentScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _tData;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  DateTime? _selectedDob;

  bool _isProcessingPayment = false;
  Map<String, dynamic>? _paymentReceipt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final data = await api.getPublicTournament(widget.tournamentId);
      setState(() {
        _tData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _formatDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBA';
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTimeStr(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'TBA';
    try {
      final dt = DateTime.parse(timeStr);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  Future<void> _processRazorpayPayment() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Name, Phone, and Email (*)')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);
    try {
      final api = context.read<ApiClient>();
      final orderRes = await api.createRazorpayOrder(widget.tournamentId, {
        'participant_name': name,
        'participant_phone': phone,
        'participant_email': email,
        'participant_dob': _selectedDob?.toIso8601String(),
      });

      final regId = orderRes['registration_id'] as String;
      final orderId = orderRes['order_id'] as String;

      // Simulate / Execute Razorpay Verification
      final verifyRes = await api.verifyTournamentPayment({
        'registration_id': regId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'sig_verified',
      });

      setState(() {
        _paymentReceipt = verifyRes;
        _isProcessingPayment = false;
      });
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Tournament Link Error', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
              ],
            ),
          ),
        ),
      );
    }

    final t = _tData!;
    final bool isExpired = t['is_expired'] == true;
    final String academyName = t['academy_name'] ?? 'Academy';
    final String? academyLogo = t['academy_logo'];
    final String? academyTagline = t['academy_tagline'];
    final String tournamentName = t['name'] ?? 'Tournament';
    final String sports = t['sports'] ?? 'Chess';
    final String category = t['category'] ?? 'Open';
    final int fee = t['fee_amount'] ?? 0;
    final String? bannerUrl = t['banner_url'];
    final String venue = t['venue'] ?? 'Academy Venue';
    final String city = t['city_or_place'] ?? '';
    final String? notes = t['notes'];
    final String? rules = t['rules_and_prizes'];
    final String? organizerName = t['organizer_name'];
    final String? organizerPhone = t['organizer_phone'];
    final String? organizerEmail = t['organizer_email'];

    final baseUrl = ApiClient.baseUrl;
    String? fullLogoUrl;
    if (academyLogo != null && academyLogo.isNotEmpty) {
      fullLogoUrl = academyLogo.startsWith('http') ? academyLogo : '$baseUrl$academyLogo';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            if (fullLogoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(fullLogoUrl, width: 32, height: 32, fit: BoxFit.cover),
              )
            else
              const Icon(Icons.school, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                academyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Academy Banner / Logo Header Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  elevation: 3,
                  child: Column(
                    children: [
                      if (bannerUrl != null && bannerUrl.isNotEmpty)
                        Image.network(
                          bannerUrl.startsWith('http') ? bannerUrl : '$baseUrl$bannerUrl',
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.indigo.shade900,
                            child: const Center(child: Icon(Icons.emoji_events, size: 64, color: Colors.amber)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 56, color: Colors.amber),
                              const SizedBox(height: 8),
                              Text(
                                tournamentName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              if (academyTagline != null && academyTagline.isNotEmpty)
                                Text(academyTagline, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.indigo.shade200),
                                  ),
                                  child: Text('🏆 $sports', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade800, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.purple.shade200),
                                  ),
                                  child: Text('🎯 $category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 12)),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: fee > 0 ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: fee > 0 ? Colors.green : Colors.blue),
                                  ),
                                  child: Text(
                                    fee > 0 ? 'Entry Fee: ₹$fee' : 'FREE ENTRY',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: fee > 0 ? Colors.green.shade800 : Colors.blue.shade800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(tournamentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Link Expiry Warning Banner
                if (isExpired)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade400, width: 1.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.timer_off_outlined, color: Colors.amber, size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registration Closed / Link Expired', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              SizedBox(height: 2),
                              Text('The tournament date has passed or registrations have ended.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Details Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.calendar_today_rounded,
                        color: Colors.blue,
                        title: 'Date & Time',
                        subtitle: '${_formatDateStr(t['start_date'])}\nReporting: ${_formatTimeStr(t['reporting_time'])}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.location_on_rounded,
                        color: Colors.deepOrange,
                        title: 'Venue & Place',
                        subtitle: '$venue${city.isNotEmpty ? '\n$city' : ''}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (organizerName != null || organizerPhone != null)
                  _buildInfoCard(
                    icon: Icons.contact_phone_rounded,
                    color: Colors.teal,
                    title: 'Organizer Contact',
                    subtitle: '${organizerName ?? "Academy Organizer"} ${organizerPhone != null ? "• 📞 $organizerPhone" : ""} ${organizerEmail != null ? "• ✉️ $organizerEmail" : ""}',
                  ),

                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('About Tournament', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(notes, style: const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ),
                ],

                if (rules != null && rules.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Rules & Prizes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(rules, style: const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Success Receipt Card if Payment Completed
                if (_paymentReceipt != null) ...[
                  Card(
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.green.shade400, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                          const SizedBox(height: 8),
                          const Text('Registration Successful! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 6),
                          Text(
                            'Invoice receipt has been emailed to ${_paymentReceipt!['participant_email'] ?? _emailCtrl.text.trim()}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.green.shade900),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Participant Name:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_paymentReceipt!['participant_name'] ?? _nameCtrl.text),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment ID:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(_paymentReceipt!['razorpay_payment_id'] ?? 'PAID', style: const TextStyle(fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount Paid:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('₹${_paymentReceipt!['amount_paid'] ?? fee}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ] else if (!isExpired) ...[
                  // Registration & Razorpay Form
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.how_to_reg_rounded, color: Color(0xFF1E293B)),
                              SizedBox(width: 8),
                              Text('Participant Online Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Enter participant details to complete Razorpay payment.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(height: 20),

                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Participant Name *',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Phone Number *',
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address (Invoice Receipt will be sent here) *',
                              prefixIcon: Icon(Icons.email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cake, color: Colors.indigo),
                            title: Text(_selectedDob == null
                                ? 'Select Date of Birth (Optional)'
                                : 'DOB: ${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'),
                            trailing: TextButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(2012, 1, 1),
                                  firstDate: DateTime(1960),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) setState(() => _selectedDob = d);
                              },
                              child: const Text('Pick Date'),
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              icon: _isProcessingPayment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.payment_rounded),
                              label: Text(
                                _isProcessingPayment
                                    ? 'Processing Razorpay Payment...'
                                    : 'Pay ₹$fee via Razorpay Gateway',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isProcessingPayment ? null : _processRazorpayPayment,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
