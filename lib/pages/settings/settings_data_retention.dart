import 'package:flutter/material.dart';
import '../../db/dbhelper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ─── Responsive scale helper ──────────────────────────────────────────────────
// Base design width: 390px (iPhone 14).
// Factor = original px / 390. All fonts, icons, and key sizes derived here.
class _F {
  static double s(BuildContext ctx, double factor) =>
      MediaQuery.of(ctx).size.width * factor;

  static double pageTitle(BuildContext ctx)    => s(ctx, 0.062); // ~24px @ 390 (was 22–26 isNarrow branch)
  static double sectionLabel(BuildContext ctx) => s(ctx, 0.038); // ~15px
  static double infoText(BuildContext ctx)     => s(ctx, 0.037); // ~14.5px
  static double accentLabel(BuildContext ctx)  => s(ctx, 0.036); // ~14px
  static double linkText(BuildContext ctx)     => s(ctx, 0.035); // ~13.5px
  static double backBtn(BuildContext ctx)      => s(ctx, 0.041); // ~16px
  static double dayBtn(BuildContext ctx)       => s(ctx, 0.036); // ~14px
  static double headerIcon(BuildContext ctx)   => s(ctx, 0.097); // ~38px (mid of 34–44 range)
  static double infoIcon(BuildContext ctx)     => s(ctx, 0.046); // ~18px
  static double linkIcon(BuildContext ctx)     => s(ctx, 0.041); // ~16px
}

class SettingsDataRetentionPage extends StatefulWidget {
  const SettingsDataRetentionPage({super.key});

  @override
  State<SettingsDataRetentionPage> createState() =>
      _SettingsDataRetentionPageState();
}

class _SettingsDataRetentionPageState
    extends State<SettingsDataRetentionPage> {
  // ── theme colours ──────────────────────────────────────────────────────────
  static const Color _bg          = Color(0xFF021E28);
  static const Color _cardBorder  = Color(0xFF1E3348);
  static const Color _accent      = Color(0xFF3DD6C0);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF8FA8BF);
  static const Color _unselectedBtnBg = Color(0xFF162230);

  // ── state ──────────────────────────────────────────────────────────────────
  int _selectedDays = 2;
  bool _isSaving    = false;

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<void> _selectDays(int days) async {
    if (_selectedDays == days || _isSaving) return;
    setState(() {
      _selectedDays = days;
      _isSaving     = true;
    });
    try {
      await DBhelper.instance.setUnsavedReadingsRetentionDays(days);
      await DBhelper.instance.deleteOldUnsavedReadings(retentionDays: days);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: sw * 0.02),
              Icon(Icons.chevron_left, color: Colors.white, size: sw * 0.072),
              SizedBox(width: sw * 0.005),
              Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _F.backBtn(context),
                ),
              ),
            ],
          ),
        ),
        leadingWidth: sw * 0.26, // scales so "Back" is never clipped
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: sw * 0.05,
            vertical: sw * 0.062,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header icon + title ────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FontAwesomeIcons.database,
                      color: _accent,
                      size: _F.headerIcon(context),
                    ),
                    SizedBox(width: sw * 0.026),
                    Text(
                      'Data Retention',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: _F.pageTitle(context),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: sw * 0.092),

              // ── Saved Readings section ─────────────────────────────────────
              _sectionLabel(context, 'Saved Readings'),
              SizedBox(height: sw * 0.026),
              _infoCard(
                children: [
                  _infoRow(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    text: 'Saved readings are stored permanently until deleted manually.',
                  ),
                  SizedBox(height: sw * 0.031),
                  _linkRow(
                    context: context,
                    label: 'Go to Samples page',
                    onTap: () => Navigator.of(context).pushNamed('/saved_samples'),
                  ),
                ],
              ),

              SizedBox(height: sw * 0.072),

              // ── Unsaved Readings section ───────────────────────────────────
              _sectionLabel(context, 'Unsaved Readings'),
              SizedBox(height: sw * 0.026),
              _infoCard(
                children: [
                  _infoRow(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    text:
                        'Readings which are NOT saved to any samples are temporarily '
                        'stored in the back-end for readings history visualization. '
                        'Select number of days to store readings before deletion.',
                  ),
                  SizedBox(height: sw * 0.051),
                  Text(
                    'Keep Unsaved Readings for:',
                    style: TextStyle(
                      color: _accent,
                      fontSize: _F.accentLabel(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: sw * 0.036),
                  _daySelector(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── sub-widgets ────────────────────────────────────────────────────────────

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: _textPrimary,
        fontSize: _F.sectionLabel(context),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.041),
      decoration: BoxDecoration(
        color: const Color.fromARGB(198, 2, 60, 81),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final sw = MediaQuery.of(context).size.width;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _textSecondary, size: _F.infoIcon(context)),
        SizedBox(width: sw * 0.026),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: const Color.fromARGB(255, 252, 252, 252),
              fontSize: _F.infoText(context),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkRow({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final sw = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(width: sw * 0.072), // aligns with info text
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            color: _accent,
            size: _F.linkIcon(context),
          ),
          SizedBox(width: sw * 0.01),
          Text(
            label,
            style: TextStyle(
              color: _accent,
              fontSize: _F.linkText(context),
              decoration: TextDecoration.underline,
              decorationColor: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _daySelector(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    const options = [1, 2, 3];

    return LayoutBuilder(
      builder: (context, constraints) {
        final btnWidth  = (constraints.maxWidth - sw * 0.041) / 3;
        final btnHeight = sw * 0.128; // ~50px @ 390 (was 44–50 isNarrow branch)

        return Row(
          children: options.map((days) {
            final isSelected = _selectedDays == days;
            return Padding(
              padding: EdgeInsets.only(
                right: days != options.last ? sw * 0.02 : 0,
              ),
              child: _DayButton(
                label: days == 1 ? '1 day' : '$days days',
                selected: isSelected,
                width: btnWidth,
                height: btnHeight,
                selectedBg: const Color.fromARGB(255, 250, 250, 250),
                unselectedBg: _unselectedBtnBg,
                selectedBorder: const Color.fromARGB(0, 61, 214, 191),
                unselectedBorder: const Color.fromARGB(0, 30, 51, 72),
                textColor: isSelected
                    ? const Color.fromARGB(255, 0, 0, 0)
                    : _textPrimary,
                fontSize: _F.dayBtn(context),
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
  final double fontSize; // responsive font size passed in
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
    required this.fontSize,
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
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}