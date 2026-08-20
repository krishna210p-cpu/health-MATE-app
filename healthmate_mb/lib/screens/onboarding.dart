import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../language_provider.dart';
import 'language_selection.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _LanguageOption {
  final String code;
  final String nativeName;
  final String englishName;
  const _LanguageOption(this.code, this.nativeName, this.englishName);
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;
  String _gender = 'female';
  String _state = '';
  String _preferredLanguage = 'en';
  bool _needsAssistance = false;
  bool _allowCriticalAlerts = true;
  bool _submitting = false;
  bool _autoValidate = false;

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Lakshadweep', 'Delhi', 'Puducherry'
  ];

  static const List<_LanguageOption> _languageOptions = [
    _LanguageOption('en', 'English', 'English'),
    _LanguageOption('hi', 'हिन्दी', 'Hindi'),
    _LanguageOption('mr', 'मराठी', 'Marathi'),
    _LanguageOption('gu', 'ગુજરાતી', 'Gujarati'),
    _LanguageOption('ta', 'தமிழ்', 'Tamil'),
  ];

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeController.forward();
    try {
      final lang = Provider.of<LanguageProvider>(context, listen: false).languageCode;
      _preferredLanguage = lang;
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _validateFirstName(_firstNameController.text) == null &&
        _validateLastName(_lastNameController.text) == null &&
        _validatePhone(_phoneController.text) == null &&
        _dob != null &&
        _state.isNotEmpty;
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) return 'First name is required';
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Last name is required';
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(text)) return 'Enter a valid 10-digit number';
    return null;
  }

  String _formatDob(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0F9D8A),
              onPrimary: Colors.white,
              onSurface: const Color(0xFF111827),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F9D8A)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _showLanguageSelection() async {
    final selected = await showModalBottomSheet<_LanguageOption>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 18),
            const Text('Choose Language', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Select your preferred app language.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            const SizedBox(height: 20),
            ..._languageOptions.map((option) {
              final selected = option.code == _preferredLanguage;
              return ListTile(
                onTap: () => Navigator.of(context).pop(option),
                leading: const Icon(Icons.language_rounded, color: Color(0xFF0F9D8A)),
                title: Text(option.nativeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text(option.englishName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF0F9D8A)) : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              );
            }).toList(),
            const SizedBox(height: 20),
          ]),
        );
      },
    );

    if (selected != null) {
      setState(() => _preferredLanguage = selected.code);
      final provider = Provider.of<LanguageProvider>(context, listen: false);
      provider.setLanguage(selected.code);
      try {
        (healthmateAppKey.currentState as dynamic)?.setLocale(Locale(selected.code));
      } catch (_) {}
    }
  }

  Future<void> _showStateSelection() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        String query = '';
        return StatefulBuilder(builder: (context, setLocalState) {
          final filtered = query.isEmpty
              ? _indianStates
              : _indianStates.where((state) => state.toLowerCase().contains(query.toLowerCase())).toList();
          return Padding(
            padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 18),
              const Align(alignment: Alignment.centerLeft, child: Text('Select State / Region', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                  hintText: 'Search states',
                ),
                onChanged: (value) => setLocalState(() => query = value),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    itemBuilder: (context, index) {
                      final stateName = filtered[index];
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(stateName),
                        title: Text(stateName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          );
        });
      },
    );

    if (selected != null && mounted) {
      setState(() => _state = selected);
    }
  }

  Future<void> _submit() async {
    setState(() => _autoValidate = true);
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields.')));
      return;
    }
    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('first_name', _firstNameController.text.trim());
    await prefs.setString('last_name', _lastNameController.text.trim());
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_dob', _dob!.toIso8601String());
    await prefs.setString('user_gender', _gender);
    await prefs.setString('user_state', _state);
    await prefs.setString('language_code', _preferredLanguage);
    await prefs.setBool('needs_assistance', _needsAssistance);
    await prefs.setBool('allow_critical_alerts', _allowCriticalAlerts);
    await prefs.setBool('onboarded', true);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.setLanguage(_preferredLanguage);
    setState(() => _submitting = false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()));
  }

  Widget _buildFieldCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                _buildLanguageCard(theme),
                const SizedBox(height: 20),
                _buildWelcomeCard(theme),
                const SizedBox(height: 28),
                _buildForm(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(ThemeData theme) {
    final option = _languageOptions.firstWhere((opt) => opt.code == _preferredLanguage, orElse: () => _languageOptions.first);
    return GestureDetector(
      onTap: _showLanguageSelection,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE8F8F2), Color(0xFFFFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD9EDE6)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0F9D8A).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.all(14),
              child: const Icon(Icons.language_rounded, color: Color(0xFF0F9D8A), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Preferred Language', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(option.nativeName, style: theme.textTheme.titleLarge?.copyWith(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(option.englishName, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B))),
              ]),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF334155), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F9D8A), Color(0xFF3EC5B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x220F9D8A), blurRadius: 24, offset: Offset(0, 20))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('HealthMate', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 28))),
        ]),
        const SizedBox(height: 24),
        Text('Welcome to your personalised healthcare companion', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 14),
        Text('Complete your profile to unlock care recommendations, alerts, and trusted guidance tailored for you.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.92), fontSize: 15, height: 1.7)),
      ]),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildFieldCard(
        child: Column(children: [
          _buildNameRow(theme),
          const SizedBox(height: 16),
          _buildPhoneField(theme),
          const SizedBox(height: 16),
          _buildDobField(theme),
          const SizedBox(height: 16),
          _buildGenderChips(theme),
          const SizedBox(height: 16),
          _buildStateField(theme),
        ]),
      ),
      const SizedBox(height: 24),
      _buildAccessibilityCard(theme),
      const SizedBox(height: 28),
      _buildGetStartedButton(theme),
    ]);
  }

  Widget _buildNameRow(ThemeData theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 540;
      return isWide
          ? Row(children: [
              Expanded(child: _buildTextField(_firstNameController, 'First Name', 'Krishna', Icons.person, _validateFirstName)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_lastNameController, 'Last Name', 'Pandey', Icons.person_outline, _validateLastName)),
            ])
          : Column(children: [
              _buildTextField(_firstNameController, 'First Name', 'Krishna', Icons.person, _validateFirstName),
              const SizedBox(height: 16),
              _buildTextField(_lastNameController, 'Last Name', 'Pandey', Icons.person_outline, _validateLastName),
            ]);
    });
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, String? Function(String?) validator) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon), floatingLabelBehavior: FloatingLabelBehavior.auto),
      validator: validator,
      autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
    );
  }

  Widget _buildPhoneField(ThemeData theme) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: '1234567890',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 10, right: 8),
          child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F9D8A), fontSize: 16)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 64),
        suffixIcon: _validatePhone(_phoneController.text) == null && _phoneController.text.trim().length == 10
            ? const Icon(Icons.check_circle, color: Color(0xFF0F9D8A))
            : null,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 10,
      validator: _validatePhone,
      autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
    );
  }

  Widget _buildDobField(ThemeData theme) {
    return GestureDetector(
      onTap: _selectDob,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            hintText: 'DD/MM/YYYY',
            prefixIcon: const Icon(Icons.calendar_month_rounded),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          controller: TextEditingController(text: _dob == null ? '' : _formatDob(_dob!)),
          validator: (_) => _dob == null ? 'Select your date of birth' : null,
          autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        ),
      ),
    );
  }

  Widget _buildGenderChips(ThemeData theme) {
    final items = [
      {'label': 'Male', 'value': 'male'},
      {'label': 'Female', 'value': 'female'},
      {'label': 'Other', 'value': 'other'},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Gender', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: items.map((item) {
        final selected = _gender == item['value'];
        return ChoiceChip(
          label: Text(item['label']!, style: TextStyle(color: selected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          selected: selected,
          selectedColor: const Color(0xFF0F9D8A),
          backgroundColor: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          onSelected: (_) => setState(() => _gender = item['value']!),
        );
      }).toList()),
    ]);
  }

  Widget _buildStateField(ThemeData theme) {
    return GestureDetector(
      onTap: _showStateSelection,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'State / Region',
            hintText: 'Select your state',
            prefixIcon: const Icon(Icons.location_on_rounded),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          controller: TextEditingController(text: _state),
          validator: (_) => _state.isEmpty ? 'Please choose a state or region' : null,
          autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        ),
      ),
    );
  }

  Widget _buildAccessibilityCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(color: const Color(0xFF0F9D8A).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.accessibility_new_rounded, color: Color(0xFF0F9D8A)),
          ),
          const SizedBox(width: 12),
          Text('Accessibility', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
        ]),
        const SizedBox(height: 18),
        _buildSwitchTile(
          title: 'Reading Assistance',
          subtitle: 'Better screen clarity and prompts for easier reading.',
          value: _needsAssistance,
          onChanged: (value) => setState(() => _needsAssistance = value),
        ),
        const Divider(height: 32, color: Color(0xFFF1F5F9)),
        _buildSwitchTile(
          title: 'Enable Voice Guidance',
          subtitle: 'Voice prompts for major actions and alerts.',
          value: _allowCriticalAlerts,
          onChanged: (value) => setState(() => _allowCriticalAlerts = value),
        ),
      ]),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45)),
        ]),
      ),
      Switch(
        value: value,
        activeColor: const Color(0xFF0F9D8A),
        inactiveTrackColor: const Color(0xFFE2E8F0),
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _buildGetStartedButton(ThemeData theme) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: _submitting || !_isFormValid ? null : _submit,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
          shadowColor: const Color(0x220F9D8A),
          backgroundColor: _isFormValid ? const Color(0xFF0F9D8A) : const Color(0xFF94D3C2),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          child: _submitting
              ? const SizedBox(key: ValueKey('loading'), width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
              : Row(key: const ValueKey('label'), mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
        ),
      ),
    );
  }
}
