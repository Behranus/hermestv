import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/services/lock_service.dart';

/// Uygulama açılışında şifre soran tam ekran kilit.
/// Doğru şifre girilene kadar ana ekran gösterilmez.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  /// Doğru şifre girilince çağrılır.
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _screenFocus = FocusNode();
  bool _obscure = true;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Kumanda/klavye desteği: rakam tuşları doğrudan şifreye yazılır,
  /// OK/Enter gönderir, Geri tuşu son karakteri siler (boşsa ekrandan çıkar).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // 0-9 rakam tuşları (kumandanın sayı tuşları dahil).
    final digit = _digitOf(key);
    if (digit != null) {
      if (_checking) return KeyEventResult.handled;
      setState(() {
        _controller.text = _controller.text + digit;
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
        _error = null;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      if (_checking) return KeyEventResult.handled;
      final t = _controller.text;
      if (t.isNotEmpty) {
        setState(() {
          _controller.text = t.substring(0, t.length - 1);
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        });
      }
      return KeyEventResult.handled;
    }

    // OK / Enter / seç → gönder.
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }

    // Geri tuşu: metin varsa son karakteri sil; yoksa uygulamadan çık.
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (_controller.text.isNotEmpty) {
        setState(() {
          _controller.text =
              _controller.text.substring(0, _controller.text.length - 1);
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  /// Rakam tuşu → karakter. Kumandanın sayı satırı/numpad tuşlarını kapsar.
  static String? _digitOf(LogicalKeyboardKey key) {
    // (LogicalKeyboardKey, const harita anahtarı olamaz — switch kullanılır.)
    if (key.keyId == LogicalKeyboardKey.digit0.keyId) return '0';
    if (key.keyId == LogicalKeyboardKey.digit1.keyId) return '1';
    if (key.keyId == LogicalKeyboardKey.digit2.keyId) return '2';
    if (key.keyId == LogicalKeyboardKey.digit3.keyId) return '3';
    if (key.keyId == LogicalKeyboardKey.digit4.keyId) return '4';
    if (key.keyId == LogicalKeyboardKey.digit5.keyId) return '5';
    if (key.keyId == LogicalKeyboardKey.digit6.keyId) return '6';
    if (key.keyId == LogicalKeyboardKey.digit7.keyId) return '7';
    if (key.keyId == LogicalKeyboardKey.digit8.keyId) return '8';
    if (key.keyId == LogicalKeyboardKey.digit9.keyId) return '9';
    if (key.keyId == LogicalKeyboardKey.numpad0.keyId) return '0';
    if (key.keyId == LogicalKeyboardKey.numpad1.keyId) return '1';
    if (key.keyId == LogicalKeyboardKey.numpad2.keyId) return '2';
    if (key.keyId == LogicalKeyboardKey.numpad3.keyId) return '3';
    if (key.keyId == LogicalKeyboardKey.numpad4.keyId) return '4';
    if (key.keyId == LogicalKeyboardKey.numpad5.keyId) return '5';
    if (key.keyId == LogicalKeyboardKey.numpad6.keyId) return '6';
    if (key.keyId == LogicalKeyboardKey.numpad7.keyId) return '7';
    if (key.keyId == LogicalKeyboardKey.numpad8.keyId) return '8';
    if (key.keyId == LogicalKeyboardKey.numpad9.keyId) return '9';
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text;
    if (input.isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await LockService.verify(input);
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      widget.onUnlocked();
    } else {
      setState(() {
        _checking = false;
        _error = 'Yanlış şifre. Tekrar dene.';
      });
      _controller.clear();
      _focus.requestFocus();
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _screenFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'IPTV Player kilitli',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Devam etmek için şifreni gir.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        obscureText: _obscure,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.password),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _checking ? null : _submit,
                          icon: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_open),
                          label: const Text('Giriş Yap'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
