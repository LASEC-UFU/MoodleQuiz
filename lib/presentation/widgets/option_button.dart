import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Botão de alternativa do quiz – responsivo e acessível.
class OptionButton extends StatelessWidget {
  final String label; // 'A', 'B', 'C'…
  final String text;
  final String htmlText;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.label,
    required this.text,
    this.htmlText = '',
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  static const _labelColors = {
    'A': Color(0xFFEF5350),
    'B': Color(0xFF42A5F5),
    'C': Color(0xFF66BB6A),
    'D': Color(0xFFFFCA28),
    'E': Color(0xFFAB47BC),
  };

  @override
  Widget build(BuildContext context) {
    final labelColor = _labelColors[label] ?? AppTheme.primary;
    final borderColor = isSelected ? labelColor : Colors.transparent;
    final bgColor =
        isSelected ? labelColor.withValues(alpha: 0.18) : AppTheme.bgCard;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: labelColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Badge da letra
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? labelColor : AppTheme.bgCardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : labelColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Texto da alternativa
                Expanded(
                  child: htmlText.isNotEmpty
                      ? HtmlWidget(
                          htmlText,
                          textStyle: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            height: 1.4,
                          ),
                          customStylesBuilder: (element) {
                            if (element.localName == 'img') {
                              return {
                                'max-width': '100%',
                                'height': 'auto',
                              };
                            }
                            if (element.localName == 'table') {
                              return {
                                'border-collapse': 'collapse',
                                'width': '100%',
                              };
                            }
                            if (element.localName == 'td' ||
                                element.localName == 'th') {
                              return {
                                'border': '1px solid #444',
                                'padding': '6px 10px',
                              };
                            }
                            return null;
                          },
                        )
                      : Text(
                          text,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: labelColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
