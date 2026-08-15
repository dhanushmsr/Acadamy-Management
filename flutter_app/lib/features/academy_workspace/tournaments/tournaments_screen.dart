import 'package:flutter/material.dart';
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

  void _showNewEventModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _NewEventFormModal(),
    ).then((_) => _loadTournaments());
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
                                        'Completed',
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
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune, color: Color(0xFF1E2142)),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tournament Subtitle Count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} ${_selectedTab == 'open' ? 'open' : 'completed'} tournament${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // Tournament List Body
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _tournaments == null
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No ${_selectedTab == 'open' ? 'open' : 'completed'} tournaments found.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final t = filtered[i];
                                return _buildTournamentCard(t);
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewEventModal,
        backgroundColor: const Color(0xFF1E2142),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
          Text(
            t.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2142),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
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
  final _notesCtrl = TextEditingController();
  final _resultUrlCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  String _eventType = 'in_house';
  String _sports = 'Chess';
  String _category = '1 Category';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _reportingTime = const TimeOfDay(hour: 12, minute: 0);

  String? _bannerFileName;
  String? _brochureFileName;
  bool _isSaving = false;

  Future<void> _pickFile(bool isBanner) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
    if (result != null) {
      setState(() {
        if (isBanner) {
          _bannerFileName = result.files.single.name;
        } else {
          _brochureFileName = result.files.single.name;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Tournament Name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'organizer_name': _organizerCtrl.text.trim(),
        'tournament_type': _eventType,
        'sports': _sports,
        'category': _category,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'venue': _venueCtrl.text.trim(),
        'fee_amount': int.tryParse(_feeCtrl.text.trim()) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'result_url': _resultUrlCtrl.text.trim(),
        'status': 'open',
      };

      await context.read<ApiClient>().createTournament(payload);
      if (mounted) Navigator.pop(context);
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

  Widget _buildInputField(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
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
                const Text('New Event', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E2142))),
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
                  _buildInputField('Tournament Name', _nameCtrl),
                  _buildInputField('Organizer Name', _organizerCtrl),

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
                        Text('Chess', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E2142))),
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
                  const Text('Start Date', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(startStr, style: const TextStyle(fontSize: 15, color: Color(0xFF1E2142))),
                          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('End Date', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) setState(() => _endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(endStr, style: const TextStyle(fontSize: 15, color: Color(0xFF1E2142))),
                          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Reporting Time', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(startStr, style: const TextStyle(fontSize: 14)),
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField('Venue', _venueCtrl, hint: 'e.g. Tenkasi Indoor Stadium'),

                  // SECTION 3: Fee Details
                  _buildSectionHeader(Icons.account_balance_wallet_outlined, 'Fee Details'),
                  _buildInputField('Fee Amount (₹)', _feeCtrl, hint: 'e.g. 500'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          children: [
                            Text(_category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputField('Notes', _notesCtrl, maxLines: 3),

                  // SECTION 4: Website Configurations
                  _buildSectionHeader(Icons.language_outlined, 'Website Configurations'),
                  _buildInputField('Result URL', _resultUrlCtrl),

                  const Text('Event Banner', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _pickFile(true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF94A3B8), style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Text(
                          _bannerFileName ?? 'Browse File',
                          style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Brochure', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _pickFile(false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF94A3B8), style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Text(
                          _brochureFileName ?? 'Browse File',
                          style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
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
                          : const Text('Save Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
