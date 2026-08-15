import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/auth/api_client.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  List<TournamentSummary>? _tournaments;
  String? _error;
  String _selectedTab = 'open'; // 'open' or 'completed'
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    try {
      final list = await context.read<ApiClient>().getTournaments();
      if (mounted) {
        setState(() {
          _tournaments = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _showNewEventModal() async {
    final result = await showModalBottomSheet<TournamentSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _NewEventFormModal(),
    );

    _loadTournaments();

    if (result != null && mounted) {
      _showCreatedUrlDialog(context, result.id, result.name);
    }
  }

  void _showCreatedUrlDialog(BuildContext context, String tournamentId, String tournamentName) {
    final publicUrl = 'https://acdmanage.vercel.app/#/tournament/$tournamentId';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Public Link Generated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your unique public URL for "$tournamentName" has been generated:'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                publicUrl,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: publicUrl));
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public URL copied to clipboard! ✅'), backgroundColor: Colors.green),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showRosterModal(TournamentSummary t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RosterModal(tournament: t),
    );
  }

  void _copyPublicLink(String tournamentId) {
    final link = 'https://acdmanage.vercel.app/#/tournament/$tournamentId';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.link, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Copied Public Tournament Link: $link')),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (_tournaments ?? []).where((t) {
      final matchesTab = (t.status.toLowerCase() == _selectedTab);
      final matchesSearch = t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.organizerName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Custom Header & Blue Bar Area
            Container(
              color: const Color(0xFFEBF4FF),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _isSearching
                            ? TextField(
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Search tournaments...',
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              )
                            : const Text(
                                'Tournaments',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2142),
                                ),
                              ),
                      ),
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search, size: 24),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) _searchQuery = '';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Open / Completed Toggle Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCEBFE),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 'open'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 'open' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: _selectedTab == 'open'
                                          ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Open',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _selectedTab == 'open' ? const Color(0xFF1E2142) : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 'completed'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 'completed' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: _selectedTab == 'completed'
                                          ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Completed / Link Expired',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _selectedTab == 'completed' ? const Color(0xFF1E2142) : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tournament List or Error
            Expanded(
              child: _tournaments == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No ${_selectedTab.capitalize()} Tournaments Found',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildTournamentCard(filtered[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewEventModal,
        backgroundColor: const Color(0xFF1E2142),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Tournament', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTournamentCard(TournamentSummary t) {
    final isThirdParty = t.tournamentType.toLowerCase().contains('third');
    final feeStr = t.totalCollected > 0 ? '₹${t.totalCollected}' : '₹${t.feeAmount ?? 0}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2142),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy Public Web Link',
                icon: const Icon(Icons.share_outlined, color: Color(0xFF2563EB)),
                onPressed: () => _copyPublicLink(t.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Badge 1: Sports ("Chess")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  t.sports,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(width: 8),
              // Badge 2: Type ("In-House" / "Third Party")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3550),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isThirdParty ? 'Third Party' : 'In-House',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              // Badge 3: Category
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  t.category,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${t.participantCount} participants',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('•', style: TextStyle(color: Colors.grey)),
              ),
              const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '$feeStr collected',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Copy Web URL'),
                  onPressed: () => _copyPublicLink(t.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2142),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: Text('Roster (${t.participantCount})'),
                  onPressed: () => _showRosterModal(t),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RosterModal extends StatefulWidget {
  final TournamentSummary tournament;

  const _RosterModal({required this.tournament});

  @override
  State<_RosterModal> createState() => _RosterModalState();
}

class _RosterModalState extends State<_RosterModal> {
  bool _loading = true;
  String? _error;
  List<dynamic> _roster = [];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    try {
      final list = await context.read<ApiClient>().getTournamentRegistrations(widget.tournament.id);
      if (mounted) {
        setState(() {
          _roster = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tournament.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Registered Participants Roster • Total: ₹${widget.tournament.totalCollected}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _roster.isEmpty
                        ? const Center(child: Text('No paid registrations yet.'))
                        : ListView.builder(
                            itemCount: _roster.length,
                            itemBuilder: (context, index) {
                              final r = _roster[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.indigo.shade50,
                                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  ),
                                  title: Text(r['participant_name'] ?? 'Participant', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('📞 ${r['participant_phone'] ?? 'N/A'} • ✉️ ${r['participant_email'] ?? 'N/A'}\nRazorpay Payment ID: ${r['razorpay_payment_id'] ?? 'PAID'}', style: const TextStyle(fontSize: 12)),
                                  trailing: Text('₹${r['amount_paid'] ?? widget.tournament.feeAmount ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _NewEventFormModal extends StatefulWidget {
  const _NewEventFormModal();

  @override
  State<_NewEventFormModal> createState() => _NewEventFormModalState();
}

class _NewEventFormModalState extends State<_NewEventFormModal> {
  final _nameCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController();
  final _organizerPhoneCtrl = TextEditingController();
  final _organizerEmailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  final _resultUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _eventType = 'in_house';
  String _sports = 'Chess';
  String _category = 'Open';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _reportingTime = const TimeOfDay(hour: 9, minute: 0);

  bool _isSaving = false;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Tournament Name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _reportingTime.hour,
        _reportingTime.minute,
      );

      final payload = {
        'name': _nameCtrl.text.trim(),
        'organizer_name': _organizerCtrl.text.trim(),
        'organizer_phone': _organizerPhoneCtrl.text.trim(),
        'organizer_email': _organizerEmailCtrl.text.trim(),
        'tournament_type': _eventType,
        'sports': _sports,
        'category': _category,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'reporting_time': repDateTime.toIso8601String(),
        'venue': _venueCtrl.text.trim(),
        'city_or_place': _cityCtrl.text.trim(),
        'fee_amount': int.tryParse(_feeCtrl.text.trim()) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'rules_and_prizes': _rulesCtrl.text.trim(),
        'result_url': _resultUrlCtrl.text.trim(),
        'banner_url': _bannerUrlCtrl.text.trim(),
        'status': 'open',
      };

      final created = await context.read<ApiClient>().createTournament(payload);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1E2142)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2142)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final startStr = "${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}";
    final endStr = "${_endDate.day.toString().padLeft(2, '0')}/${_endDate.month.toString().padLeft(2, '0')}/${_endDate.year}";
    final timeStr = _reportingTime.format(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Create Dynamic Tournament', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2142))),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 20, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: Basic Details
                  _buildSectionHeader(Icons.emoji_events_outlined, 'Basic Details'),
                  _buildInputField('Tournament Name *', _nameCtrl, hint: 'e.g. Annual Chess Championship 2026'),
                  _buildInputField('Organizer Name', _organizerCtrl, hint: 'e.g. Master Rajesh'),
                  Row(
                    children: [
                      Expanded(child: _buildInputField('Organizer Phone', _organizerPhoneCtrl, hint: '9876543210', keyboardType: TextInputType.phone)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInputField('Organizer Email', _organizerEmailCtrl, hint: 'organizer@academy.com', keyboardType: TextInputType.emailAddress)),
                    ],
                  ),

                  const Text('Sports', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(0xFFF59E0B),
                          child: Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text('Chess / General Sports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2142))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Event Type', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _eventType = 'in_house'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: _eventType == 'in_house' ? const Color(0xFFEFF6FF) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _eventType == 'in_house' ? const Color(0xFF2563EB) : Colors.transparent),
                          ),
                          child: Text(
                            'In-House',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _eventType == 'in_house' ? const Color(0xFF2563EB) : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _eventType = 'third_party'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: _eventType == 'third_party' ? const Color(0xFFEFF6FF) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _eventType == 'third_party' ? const Color(0xFF2563EB) : Colors.transparent),
                          ),
                          child: Text(
                            'Third Party',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _eventType == 'third_party' ? const Color(0xFF2563EB) : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // SECTION 2: Date & Venue
                  _buildSectionHeader(Icons.calendar_today_outlined, 'Date & Venue'),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (picked != null) setState(() => _startDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(startStr, style: const TextStyle(fontSize: 14, color: Color(0xFF1E2142))),
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (picked != null) setState(() => _endDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(endStr, style: const TextStyle(fontSize: 14, color: Color(0xFF1E2142))),
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Reporting Time', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _reportingTime);
                      if (picked != null) setState(() => _reportingTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(timeStr, style: const TextStyle(fontSize: 14)),
                          const Icon(Icons.access_time, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField('Venue / Stadium Name', _venueCtrl, hint: 'e.g. Tenkasi Indoor Stadium'),
                  _buildInputField('City / Place', _cityCtrl, hint: 'e.g. Tenkasi / Chennai'),

                  // SECTION 3: Fee Details
                  _buildSectionHeader(Icons.account_balance_wallet_outlined, 'Fee Details & Rules'),
                  _buildInputField('Entry Fee Amount (₹) *', _feeCtrl, hint: 'e.g. 500', keyboardType: TextInputType.number),
                  _buildInputField('Rules, Format & Prizes', _rulesCtrl, hint: 'e.g. 5 Rounds Swiss League, Trophies for Top 10...', maxLines: 3),
                  _buildInputField('Additional Notes', _notesCtrl, maxLines: 2),

                  // SECTION 4: Website Configurations
                  _buildSectionHeader(Icons.language_outlined, 'Website Media Banner & URLs'),
                  _buildInputField('Event Banner Image URL', _bannerUrlCtrl, hint: 'https://example.com/banner.jpg'),
                  _buildInputField('Result / Chess-Results URL', _resultUrlCtrl, hint: 'https://chess-results.com/...'),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2142),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Publish Tournament Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
