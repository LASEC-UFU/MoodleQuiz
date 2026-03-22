import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../data/datasources/gsheet_datasource.dart';

/// Tela de configuração inicial – inserir URL do Apps Script.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    AppConfig.gsheetScriptUrl = _urlCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gsheet_url', AppConfig.gsheetScriptUrl);

    // Carrega configurações remotas (moodle_url, quiz_title, teacher_token…)
    try {
      final ds = context.read<IGSheetDatasource>();
      final cfg = await ds.getConfig();
      AppConfig.loadFromMap(cfg);
    } catch (_) {
      // GSheets indisponível – segue com defaults
    }

    if (mounted) context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: Responsive.horizontalPadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 16),
                    Text(
                      'Configuração Inicial',
                      style: AppTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cole a URL do seu Google Apps Script abaixo.',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'URL do Apps Script',
                        prefixIcon: Icon(Icons.link),
                        hintText:
                            'https://script.google.com/macros/s/…/exec',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Insira a URL do script';
                        }
                        if (!v.startsWith('https://script.google.com')) {
                          return 'URL inválida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Salvar e Continuar'),
                    ),
                    const SizedBox(height: 24),
                    _HelpCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline,
                color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text('Como obter a URL',
                style: TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          const Text(
            '1. Abra a planilha Google Sheets fornecida\n'
            '2. Menu → Extensões → Apps Script\n'
            '3. Clique em "Implantar" → "Nova implantação"\n'
            '4. Tipo: App da Web • Acesso: Qualquer pessoa\n'
            '5. Copie a URL gerada e cole acima',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2)
        ],
      ),
      child: const Icon(Icons.quiz, color: Colors.white, size: 44),
    );
  }
}
