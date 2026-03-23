import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _mapError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRegisterInfo() {
    const developerEmail = 'rodolfojscampos@gmail.com';
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                color: scheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cadastro por solicitacao',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Para cadastrar um novo usuario, envie uma solicitacao para o desenvolvedor.',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: developerEmail),
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'E-mail copiado para a area de transferencia.',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            developerEmail,
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(dialogContext).textTheme.bodyMedium
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _mapError(String code) {
    return switch (code) {
      'user-not-found' => 'Nenhum usuario encontrado com este e-mail.',
      'wrong-password' => 'Senha incorreta.',
      'invalid-credential' => 'E-mail ou senha invalidos.',
      'email-already-in-use' => 'Este e-mail ja esta cadastrado.',
      'weak-password' => 'Senha muito fraca. Use pelo menos 6 caracteres.',
      'invalid-email' => 'Formato de e-mail invalido.',
      'too-many-requests' =>
        'Muitas tentativas. Aguarde antes de tentar novamente.',
      'network-request-failed' => 'Sem conexao. Verifique sua internet.',
      _ => 'Ocorreu um erro. Tente novamente.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSmall = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 24 : 0,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / ícone
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Simple ERP',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bem-vindo de volta',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 32),
                // Card de formulário
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // E-mail
                          TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe o e-mail';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'E-mail invalido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          // Senha
                          TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe a senha';
                              }
                              return null;
                            },
                          ),
                          // Mensagem de erro
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: scheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: scheme.onErrorContainer,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Manter-se conectado
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? true,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Manter-me conectado'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Botão principal
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Entrar',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Alternar entre login / cadastro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Nao tem uma conta?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _showRegisterInfo,
                      child: const Text('Cadastrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
