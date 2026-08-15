import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/auth/api_client.dart';
import '../../core/auth/auth_state.dart';
import 'people/people_screen.dart';
import 'expenses/expenses_screen.dart';
import 'materials/materials_screen.dart';
import 'tournaments/tournaments_screen.dart';
import 'attendance/day_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DashboardStats? _stats;
  String? _error;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % 4;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stats = await context.read<ApiClient>().getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _error = null;
        });
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.toLowerCase().contains('suspended')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your academy account has been suspended by Super Admin.')),
          );
          context.read<AuthState>().logout();
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _uploadLogo() async {
    final authState = context.read<AuthState>();
    final aid = authState.academyId;
    if (aid == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploadingLogo = true);
        await context.read<ApiClient>().uploadLogo(
              aid,
              result.files.single.bytes!,
              result.files.single.name,
            );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _deleteLogo() async {
    final authState = context.read<AuthState>();
    final aid = authState.academyId;
    if (aid == null) return;

    try {
      setState(() => _isUploadingLogo = true);
      await context.read<ApiClient>().deleteLogo(aid);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo deleted. Reverted to default app logo!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  void _showLogoOptions() {
    final hasLogo = _stats?.academyLogoUrl != null && _stats!.academyLogoUrl!.isNotEmpty;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Manage Academy Logo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Upload New Logo'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadLogo();
              },
            ),
            if (hasLogo)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Logo (Revert to App Logo)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteLogo();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKingChessIcon({double size = 48}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: size * 0.8,
          height: size * 0.8,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final logoUrl = _stats?.academyLogoUrl;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    final academyName = _stats?.academyName ?? 'Academy Workspace';
    final address = _stats?.academyAddress ?? '';
    final phone = _stats?.academyPhone ?? '';
    final email = _stats?.academyEmail ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  academyName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2142),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty || email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        Icon(Icons.phone_outlined, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                      if (phone.isNotEmpty && email.isNotEmpty)
                        Text('  •  ', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      if (email.isNotEmpty) ...[
                        Icon(Icons.email_outlined, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showLogoOptions,
            child: Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: hasLogo
                        ? Image.network(
                            '${ApiClient.baseUrl.replaceAll('/api/v1', '')}$logoUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildKingChessIcon(size: 52),
                          )
                        : _buildKingChessIcon(size: 52),
                  ),
                ),
                if (_isUploadingLogo)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBannerCard() {
    final income = _stats?.totalIncome ?? 0;
    final dues = _stats?.outstandingDues ?? 0;
    final totalStudents = _stats?.totalStudents ?? 0;
    final totalBatches = _stats?.totalBatches ?? 0;

    final slides = [
      _buildMetricSlide(
        icon: Icons.currency_rupee,
        iconBgColor: const Color(0xFF10B981),
        title: 'Total credit',
        value: '₹$income',
        valueColor: const Color(0xFF1E2142),
      ),
      _buildMetricSlide(
        icon: Icons.warning_amber_rounded,
        iconBgColor: const Color(0xFFEF4444),
        title: 'Outstanding dues',
        value: '₹$dues',
        valueColor: const Color(0xFF1E2142),
      ),
      _buildMetricSlide(
        icon: Icons.groups_outlined,
        iconBgColor: const Color(0xFF3B82F6),
        title: 'Active Students',
        value: '$totalStudents Students',
        valueColor: const Color(0xFF1E2142),
      ),
      _buildMetricSlide(
        icon: Icons.class_outlined,
        iconBgColor: const Color(0xFF8B5CF6),
        title: 'Total Batches',
        value: '$totalBatches Active Batches',
        valueColor: const Color(0xFF1E2142),
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEBF4FF),
            Color(0xFFDCEBFE),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.15,
              child: Icon(Icons.sports_esports, size: 180, color: Colors.blue[800]),
            ),
          ),
          PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: slides,
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final isActive = _currentPage == (index % 4);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF1E2142) : Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSlide({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Student',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PeopleScreen()),
            ),
          ),
          _buildQuickActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'Expense',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
          ),
          _buildQuickActionButton(
            icon: Icons.shopping_cart_outlined,
            label: 'Order',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialsScreen()),
            ),
          ),
          _buildQuickActionButton(
            icon: Icons.emoji_events_outlined,
            label: 'Tournament',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TournamentsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1E2142), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysClassesSection() {
    final dateToday = DateTime.now().toString().split(' ')[0];
    final classes = _stats?.todaysClasses ?? [];

    // Beautiful gradient color pairs for each batch card
    final gradientColors = [
      [const Color(0xFF6DD5FA), const Color(0xFF2980B9)], // Ocean Blue
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)], // Lavender Pink
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)], // Mint Green
      [const Color(0xFFF6D365), const Color(0xFFFDA085)], // Sunrise Orange
      [const Color(0xFFFA709A), const Color(0xFFFEE140)], // Pink Lemonade
      [const Color(0xFF667EEA), const Color(0xFF764BA2)], // Royal Purple
      [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Emerald
      [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)], // Berry Blue
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Text(
                'Your Batches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2142),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2142),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${classes.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        classes.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('No batches created yet. Add one from the People tab!',
                    style: TextStyle(color: Colors.grey)),
              )
            : SizedBox(
                height: 175,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  itemBuilder: (ctx, i) {
                    final c = classes[i] as Map<String, dynamic>;
                    final gc = gradientColors[i % gradientColors.length];
                    final isToday = c['is_today'] == true;

                    return Container(
                      width: 270,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gc,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: gc[0].withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -15,
                            top: -15,
                            child: Opacity(
                              opacity: 0.15,
                              child: Icon(Icons.extension, size: 120, color: Colors.white),
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
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        c['category']?.toString() ?? 'Chess',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: gc[1],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (isToday)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle, size: 6, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text('TODAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  c['name']?.toString() ?? 'Batch',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        c['timing']?.toString() ?? 'Timing not set',
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DayAttendanceScreen(
                                        date: dateToday,
                                        initialBatchId: c['id']?.toString(),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Mark Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: gc[1],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection() {
    final transactions = _stats?.recentTransactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2142),
            ),
          ),
        ),
        transactions.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No transactions logged yet.', style: TextStyle(color: Colors.grey)),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: transactions.map((t) {
                    final isIncome = t['is_income'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isIncome ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isIncome ? Icons.account_balance_wallet_outlined : Icons.money_off_outlined,
                              color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['title']?.toString() ?? 'Transaction',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2142),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t['month']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                t['amount']?.toString() ?? '₹0',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t['date']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _stats == null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildTopBannerCard(),
              _buildQuickActionBar(),
              _buildTodaysClassesSection(),
              _buildRecentTransactionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
