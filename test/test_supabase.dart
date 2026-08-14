import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase URL format test', () {
    const url = "https://gtwirhvswhslljbfvnoe.supabase.co";
    expect(Uri.parse(url).isAbsolute, isTrue);
  });
}
