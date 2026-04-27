import 'package:flutter/material.dart';
import '../../db/dbhelper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsDataRetentionPage extends StatefulWidget {
  const SettingsDataRetentionPage({super.key});

  @override
  State<SettingsDataRetentionPage> createState() =>
      _SettingsDataRetentionPageState();
}

class _SettingsDataRetentionPageState
    extends State<SettingsDataRetentionPage> {
  // ── theme colours (matching the dark teal design) ──────────────────────────
  static const Color _bg = Color(0xFF0D1B2A);
  static const Color _card = Color(0xFF112233);
  static const Color _cardBorder = Color(0xFF1E3348);
  static const Color _accent = Color(0xFF3DD6C0); // teal
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF8FA8BF);
  static const Color _selectedBtnBg = Color(0xFF2A3F52);
  static const Color _unselectedBtnBg = Color(0xFF162230);

  // ── state ──────────────────────────────────────────────────────────────────
  int _selectedDays = 2; // default shown in screenshot
  bool _isSaving = false;

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<void> _selectDays(int days) async {
    if (_selectedDays == days || _isSaving) return;
    setState(() {
      _selectedDays = days;
      _isSaving = true;
    });

    try {
      await DBhelper.instance.setUnsavedReadingsRetentionDays(days);
      // Immediately apply: remove readings that now fall outside the new window
      await DBhelper.instance.deleteOldUnsavedReadings(retentionDays: days);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 400;

    return Scaffold(
      backgroundColor: Color(0XFF021E28),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header icon + title ────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.database, color: Color(0XFF3DD6C0), size: isNarrow ? 34: 44),
                    const SizedBox(width: 10),
                    Text(
                      'Data Retention',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: isNarrow ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Saved Readings section ─────────────────────────────────────
              _sectionLabel('Saved Readings'),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Saved readings are stored permanently until deleted manually.',
                  ),
                  const SizedBox(height: 12),
                  _linkRow(
                    label: 'Go to Samples page',
                    onTap: () {
                      // Navigate to Samples page
                      // Navigator.of(context).pushNamed('/samples');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Unsaved Readings section ───────────────────────────────────
              _sectionLabel('Unsaved Readings'),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Readings which are NOT saved to any samples are temporarily '
                        'stored in the back-end for readings history visualization. '
                        'Select number of days to store readings before deletion.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Keep Unsaved Readings for:',
                    style: TextStyle(
                      color: _accent,
                      fontSize: isNarrow ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _daySelector(isNarrow),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── sub-widgets ────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0XFF021E28),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textPrimary, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Back',
        style: TextStyle(color: _textPrimary, fontSize: 16),
      ),
      titleSpacing: 0,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(198, 2, 60, 81),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color.fromARGB(255, 252, 252, 252),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkRow({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          const SizedBox(width: 28), // aligns with info text
          const Icon(Icons.subdirectory_arrow_right_rounded,
              color: _accent, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _accent,
              fontSize: 13.5,
              decoration: TextDecoration.underline,
              decorationColor: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _daySelector(bool isNarrow) {
    const options = [1, 2, 3];

    return LayoutBuilder(
      builder: (context, constraints) {
        final btnWidth = (constraints.maxWidth - 16) / 3;

        return Row(
          children: options.map((days) {
            final isSelected = _selectedDays == days;
            return Padding(
              padding: EdgeInsets.only(right: days != options.last ? 8 : 0),
              child: _DayButton(
                label: days == 1 ? '1 day' : '$days days',
                selected: isSelected,
                width: btnWidth,
                height: isNarrow ? 44 : 50,
                selectedBg: const Color.fromARGB(255, 250, 250, 250),
                unselectedBg: _unselectedBtnBg,
                selectedBorder: const Color.fromARGB(0, 61, 214, 191),
                unselectedBorder: const Color.fromARGB(0, 30, 51, 72),
                textColor: isSelected ? Color.fromARGB(255, 0, 0, 0) : _textPrimary,
                onTap: () => _selectDays(days),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Isolated day-selector button ──────────────────────────────────────────────

class _DayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final double width;
  final double height;
  final Color selectedBg;
  final Color unselectedBg;
  final Color selectedBorder;
  final Color unselectedBorder;
  final Color textColor;
  final VoidCallback onTap;

  const _DayButton({
    required this.label,
    required this.selected,
    required this.width,
    required this.height,
    required this.selectedBg,
    required this.unselectedBg,
    required this.selectedBorder,
    required this.unselectedBorder,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? selectedBorder : unselectedBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}