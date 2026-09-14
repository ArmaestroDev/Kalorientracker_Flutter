import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalorientracker_flutter/data/models/activity_entry.dart';
import 'package:kalorientracker_flutter/data/models/calorie_goals.dart';
import 'package:kalorientracker_flutter/data/models/chat_message.dart';
import 'package:kalorientracker_flutter/data/models/food_entry.dart';
import 'package:kalorientracker_flutter/data/models/user_profile.dart';
import 'package:kalorientracker_flutter/data/models/weight_entry.dart';
import 'package:kalorientracker_flutter/data/services/claude_api_service.dart';
import 'package:kalorientracker_flutter/data/services/gemini_api_service.dart';
import 'package:kalorientracker_flutter/data/services/generative_service.dart';
import 'package:kalorientracker_flutter/data/services/openai_compatible_service.dart';
import 'package:kalorientracker_flutter/logic/coach_tools.dart';
import 'package:kalorientracker_flutter/logic/history_data.dart';
import 'package:kalorientracker_flutter/logic/nutrition_stats.dart';

FoodEntry food(String name, int kcal, DateTime date, {int protein = 20}) =>
    FoodEntry(
      name: name,
      calories: kcal,
      protein: protein,
      carbs: 10,
      fat: 5,
      date: date,
    );

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  // Monday 14 Sep 2026 – Sunday 20 Sep 2026
  final monday = DateTime(2026, 9, 14);
  const goals = CalorieGoals(
    calories: 2300,
    proteinGrams: 160,
    carbsGrams: 250,
    fatGrams: 70,
  );

  group('NutritionStats', () {
    final foods = [
      food('Frühstück', 700, monday),
      food('Mensa', 1500, monday),
      food('Döner', 900, addDays(monday, 1)),
      food('Pizza', 2800, addDays(monday, 3)),
    ];
    final activities = [
      ActivityEntry(name: 'BJJ', caloriesBurned: 600, date: addDays(monday, 1)),
    ];

    test('daily includes empty days', () {
      final days = NutritionStats.daily(
        foods,
        activities,
        monday,
        addDays(monday, 4),
      );
      expect(days.map((d) => d.calories), [2200, 900, 0, 2800, 0]);
      expect(days[1].burned, 600);
      expect(days[2].isLogged, isFalse);
    });

    test('week status: consumed, remaining and per remaining day', () {
      final days = NutritionStats.daily(
        foods,
        activities,
        monday,
        addDays(monday, 6),
      );
      final week = NutritionStats.weekStatus(
        days,
        addDays(monday, 3),
        dailyGoal: 2300,
        eatBackActivity: false,
      );
      expect(week.consumed, 5900);
      expect(week.budget, 16100);
      expect(week.remaining, 10200);
      expect(week.remainingDays, 4);
      expect(week.perRemainingDay, 2550);
      expect(week.unloggedPastDays, 1);
    });

    test('eating back activity raises the budget', () {
      final days = NutritionStats.daily(
        foods,
        activities,
        monday,
        addDays(monday, 6),
      );
      final week = NutritionStats.weekStatus(
        days,
        addDays(monday, 3),
        dailyGoal: 2300,
        eatBackActivity: true,
      );
      expect(week.budget, 16700);
    });

    test('weekly and monthly grouping', () {
      final days = NutritionStats.daily(
        foods,
        activities,
        DateTime(2026, 8, 30),
        addDays(monday, 3),
      );
      final weeks = NutritionStats.weekly(
        days,
        dailyGoal: 2300,
        eatBackActivity: false,
      );
      expect(weeks.map((w) => w.start), [
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 7),
        monday,
      ]);
      expect(weeks.last.calories, 5900);
      expect(weeks.last.loggedDays, 3);
      expect(weeks.last.loggedBalance, 5900 - 3 * 2300);

      final months = NutritionStats.monthly(
        days,
        dailyGoal: 2300,
        eatBackActivity: false,
      );
      expect(months.map((m) => m.start.month), [8, 9]);
      expect(months.last.end, DateTime(2026, 9, 30));
    });

    test('weight trend is a trailing 7-day average', () {
      final trend = NutritionStats.weightTrend([
        WeightEntry(date: monday, weightKg: 82),
        WeightEntry(date: addDays(monday, 1), weightKg: 81),
        WeightEntry(date: addDays(monday, 8), weightKg: 80),
      ]);
      expect(trend.map((t) => t.average), [82, 81.5, 80]);
    });

    test('history ranges start where expected', () {
      final today = addDays(monday, 3);
      expect(HistoryRange.days14.startFor(today), addDays(today, -13));
      expect(HistoryRange.weeks12.startFor(today), addDays(monday, -77));
      expect(HistoryRange.months12.startFor(today), DateTime(2025, 10));
    });
  });

  group('CoachTools', () {
    final today = addDays(monday, 3);
    final foods = [
      food('Skyr natur', 160, monday, protein: 28),
      food('Döner', 750, monday, protein: 35),
      food('Döner', 800, addDays(monday, 2), protein: 36),
      food('Apfel', 80, today, protein: 0),
    ];
    final tools = CoachTools(
      loadFoods: (s, e) async => foods
          .where((f) => !f.date.isBefore(s) && !f.date.isAfter(e))
          .toList(),
      loadActivities: (s, e) async => [],
      loadWeights: (s, e) async => [
        WeightEntry(date: monday, weightKg: 82.0),
        WeightEntry(date: today, weightKg: 81.4),
      ].where((w) => !w.date.isBefore(s) && !w.date.isAfter(e)).toList(),
      profile: const UserProfile(age: 20, weightKg: 82, heightCm: 177),
      goals: goals,
      today: today,
    );

    test('definitions have unique names and object schemas', () {
      final names = CoachTools.definitions.map((t) => t.name).toSet();
      expect(names.length, CoachTools.definitions.length);
      for (final t in CoachTools.definitions) {
        expect(t.parameters['type'], 'object');
      }
    });

    test('get_day_log returns meals, totals and budget', () async {
      final result = await tools.execute('get_day_log', {'date': '2026-09-14'});
      expect(result['wochentag'], 'Montag');
      expect((result['mahlzeiten'] as List).length, 2);
      expect((result['summe'] as Map)['kcal'], 910);
      expect(result['differenz_kcal'], 910 - 2300);
      expect(result['gewicht_kg'], 82.0);
    });

    test('get_period_summary groups by week', () async {
      final result = await tools.execute('get_period_summary', {
        'start_date': '2026-09-14',
        'end_date': '2026-09-17',
        'group_by': 'week',
      });
      final total = result['gesamt'] as Map;
      expect(total['kcal'], 1790);
      expect(total['geloggte_tage'], 3);
      expect((result['gruppen'] as List).length, 1);
    });

    test('get_period_summary refuses long day grouping', () async {
      final result = await tools.execute('get_period_summary', {
        'start_date': '2026-01-01',
        'end_date': '2026-09-17',
        'group_by': 'day',
      });
      expect(result['error'], contains('week'));
    });

    test('search_meals and get_top_foods', () async {
      final search = await tools.execute('search_meals', {'query': 'döner'});
      expect(search['anzahl_treffer'], 2);
      expect(search['kcal_gesamt'], 1550);

      final top = await tools.execute('get_top_foods', {
        'start_date': '2026-09-01',
        'end_date': '2026-09-17',
      });
      final first = (top['meiste_kalorien'] as List).first as Map;
      expect(first['name'], 'Döner');
      expect(first['anzahl'], 2);
    });

    test('invalid arguments return an error instead of throwing', () async {
      expect((await tools.execute('get_day_log', {}))['error'], isNotNull);
      expect((await tools.execute('nope', {}))['error'], isNotNull);
    });
  });

  group('tool calling loops', () {
    const tool = AiTool(
      name: 'get_day_log',
      description: 'Tag',
      parameters: {
        'type': 'object',
        'properties': {
          'date': {'type': 'string'},
        },
        'required': ['date'],
      },
    );
    final calls = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>> executor(
      String name,
      Map<String, dynamic> args,
    ) async {
      calls.add({'name': name, ...args});
      return {'kcal': 910};
    }

    AiRequest request() => AiRequest(
      system: 's',
      messages: [ChatMessage(role: ChatRole.user, text: 'Was gab es Montag?')],
      tools: const [tool],
      onToolCall: executor,
    );

    setUp(calls.clear);

    test('Claude returns tool results and keeps assistant blocks', () async {
      final bodies = <Map<String, dynamic>>[];
      final service = ClaudeApiService(
        'k',
        'claude-opus-5',
        client: MockClient((r) async {
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          if (bodies.length == 1) {
            return http.Response(
              jsonEncode({
                'stop_reason': 'tool_use',
                'content': [
                  {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
                  {
                    'type': 'tool_use',
                    'id': 'tu_1',
                    'name': 'get_day_log',
                    'input': {'date': '2026-09-14'},
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'text', 'text': 'Du hattest 910 kcal.'},
              ],
            }),
            200,
          );
        }),
      );

      expect(await service.generate(request()), 'Du hattest 910 kcal.');
      expect(calls.single, {'name': 'get_day_log', 'date': '2026-09-14'});
      expect((bodies.first['tools'] as List).first['input_schema'], isNotNull);
      final second = bodies[1]['messages'] as List;
      expect((second[1]['content'] as List).first['type'], 'thinking');
      final result = (second[2]['content'] as List).first as Map;
      expect(result['type'], 'tool_result');
      expect(result['tool_use_id'], 'tu_1');
      expect(jsonDecode(result['content'] as String), {'kcal': 910});
    });

    test('OpenAI sends tool messages with the call id', () async {
      final bodies = <Map<String, dynamic>>[];
      final service = OpenAiCompatibleService.openAi(
        'k',
        'gpt-5.4-mini',
        client: MockClient((r) async {
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          if (bodies.length == 1) {
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content': null,
                      'tool_calls': [
                        {
                          'id': 'call_1',
                          'type': 'function',
                          'function': {
                            'name': 'get_day_log',
                            'arguments': '{"date":"2026-09-14"}',
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '910 kcal'},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(await service.generate(request()), '910 kcal');
      expect(calls.single['date'], '2026-09-14');
      final messages = bodies[1]['messages'] as List;
      expect(messages.last['role'], 'tool');
      expect(messages.last['tool_call_id'], 'call_1');
      expect(
        ((bodies.first['tools'] as List).first as Map)['type'],
        'function',
      );
    });

    test(
      'Gemini echoes the model content and sends functionResponse',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final service = GeminiApiService(
          'k',
          'gemini-3.8-flash',
          client: MockClient((r) async {
            bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
            if (bodies.length == 1) {
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'role': 'model',
                        'parts': [
                          {
                            'functionCall': {
                              'name': 'get_day_log',
                              'args': {'date': '2026-09-14'},
                            },
                            'thoughtSignature': 'abc',
                          },
                        ],
                      },
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': '910 kcal'},
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );

        expect(await service.generate(request()), '910 kcal');
        final contents = bodies[1]['contents'] as List;
        expect(
          ((contents[1]['parts'] as List).first as Map)['thoughtSignature'],
          'abc',
        );
        final response =
            ((contents[2]['parts'] as List).first as Map)['functionResponse']
                as Map;
        expect(response['name'], 'get_day_log');
        expect(response['response'], {'kcal': 910});
      },
    );

    test('endless tool calls stop with a readable error', () async {
      final service = ClaudeApiService(
        'k',
        'claude-sonnet-5',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'stop_reason': 'tool_use',
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'x',
                  'name': 'get_day_log',
                  'input': {'date': '2026-09-14'},
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect(() => service.generate(request()), throwsA(isA<AiException>()));
    });
  });
}
