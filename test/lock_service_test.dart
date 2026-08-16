import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/services/lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('varsayılan şifre doğru çalışır', () async {
    expect(await LockService.isEnabled(), isTrue);
    expect(await LockService.verify('Berjin.2017'), isTrue);
    expect(await LockService.verify('yanlis'), isFalse);
    expect(await LockService.verify(''), isFalse);
  });

  test('şifre değiştirilebilir', () async {
    await LockService.changePassword('YeniSifre.42');
    expect(await LockService.verify('YeniSifre.42'), isTrue);
    expect(await LockService.verify('Berjin.2017'), isFalse);
  });

  test('boş şifre kabul edilmez', () async {
    expect(
      () => LockService.changePassword('   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('kilit açılıp kapatılabilir', () async {
    await LockService.setEnabled(false);
    expect(await LockService.isEnabled(), isFalse);
    await LockService.setEnabled(true);
    expect(await LockService.isEnabled(), isTrue);
  });

  test('varsayılana dönüş eski şifreyi geçerli kılar', () async {
    await LockService.changePassword('YeniSifre.42');
    await LockService.resetToDefault();
    expect(await LockService.verify('Berjin.2017'), isTrue);
    expect(await LockService.verify('YeniSifre.42'), isFalse);
  });
}
