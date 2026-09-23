import 'package:everglow/shared/utils/draft_text_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DraftTextController.saveDelay = Duration.zero;
  });

  tearDown(() {
    DraftTextController.saveDelay = const Duration(milliseconds: 500);
  });

  Future<String?> storedDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('draft:$key');
  }

  test('loadDraft restores saved words into an empty field', () async {
    SharedPreferences.setMockInitialValues({
      'draft:chat:sanctuary': 'half-typed hello',
    });
    final input = DraftTextController('chat:sanctuary');
    addTearDown(input.dispose);

    await input.loadDraft();
    expect(input.text, 'half-typed hello');
  });

  test('loadDraft never overwrites words already in the field', () async {
    SharedPreferences.setMockInitialValues({
      'draft:chat:sanctuary': 'stale saved words',
    });
    final input = DraftTextController('chat:sanctuary', text: 'fresh words');
    addTearDown(input.dispose);

    await input.loadDraft();
    expect(input.text, 'fresh words');
  });

  test('typing is written to the device shortly after', () async {
    final input = DraftTextController('journal:new:content');
    addTearDown(input.dispose);
    await input.loadDraft();

    input.text = 'dear diary';
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await storedDraft('journal:new:content'), 'dear diary');
  });

  test('clearing the field removes the saved draft', () async {
    SharedPreferences.setMockInitialValues({'draft:starlight:drop': 'a wish'});
    final input = DraftTextController('starlight:drop');
    addTearDown(input.dispose);
    await input.loadDraft();
    expect(input.text, 'a wish');

    input.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await storedDraft('starlight:drop'), isNull);
  });

  test('clearDraft forgets the words after a real send', () async {
    final input = DraftTextController('chat:sanctuary');
    addTearDown(input.dispose);
    await input.loadDraft();

    input.text = 'sent message';
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await storedDraft('chat:sanctuary'), 'sent message');

    await input.clearDraft();
    expect(input.text, isEmpty);
    expect(await storedDraft('chat:sanctuary'), isNull);
  });
}
