/// T-H7：自製 Gherkin runner（BE）——解析 `.feature` 檔並以 dsl.md 登記之句型執行。
///
/// 支援：Feature/Background/Scenario/Scenario Outline + Examples/標籤（@）/步驟關鍵字
/// Given-When-Then-And-But。句型綁定以 `{param}` 佔位（轉為具名 regex 群組）。
/// 新句型必先登記 `specs/plan/tests/dsl.md`（tasks.md §5-4）。
library;

class GherkinStep {
  const GherkinStep(this.keyword, this.text);
  final String keyword;
  final String text;
}

class GherkinScenario {
  const GherkinScenario({
    required this.name,
    required this.tags,
    required this.steps,
    required this.isOutline,
    required this.examples,
  });

  final String name;
  final Set<String> tags;
  final List<GherkinStep> steps;
  final bool isOutline;

  /// Outline 的 Examples 資料列（key → value）；非 Outline 為 null。
  final List<Map<String, String>>? examples;
}

class GherkinDocument {
  const GherkinDocument({
    required this.featureName,
    required this.featureTags,
    required this.background,
    required this.scenarios,
  });

  final String featureName;
  final Set<String> featureTags;
  final List<GherkinStep> background; // 套用於每個情境之前
  final List<GherkinScenario> scenarios;
}

class GherkinParser {
  GherkinParser._();

  static GherkinDocument parse(String source) {
    final featureTags = <String>{};
    var featureName = '';
    final background = <GherkinStep>[];
    final scenarios = <GherkinScenario>[];

    var pendingTags = <String>{};
    var mode = _Mode.header;
    var scenarioName = '';
    var scenarioTags = <String>{};
    var scenarioSteps = <GherkinStep>[];
    var isOutline = false;
    List<Map<String, String>>? examples;
    List<String>? examplesHeader;

    void flushScenario() {
      if (scenarioName.isEmpty) return;
      scenarios.add(GherkinScenario(
        name: scenarioName,
        tags: scenarioTags,
        steps: scenarioSteps,
        isOutline: isOutline,
        examples: examples,
      ));
      scenarioName = '';
      scenarioTags = <String>{};
      scenarioSteps = <GherkinStep>[];
      isOutline = false;
      examples = null;
      examplesHeader = null;
    }

    for (var raw in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('"""')) continue;

      if (line.startsWith('@')) {
        pendingTags.addAll(line.split(RegExp(r'\s+')).where((t) => t.startsWith('@')));
        continue;
      }

      if (line.startsWith('Feature:')) {
        featureName = line.substring('Feature:'.length).trim();
        featureTags.addAll(pendingTags);
        pendingTags = {};
        mode = _Mode.header;
        continue;
      }

      if (line.startsWith('Background:')) {
        mode = _Mode.background;
        pendingTags = {};
        continue;
      }

      if (line.startsWith('Scenario Outline:')) {
        flushScenario();
        scenarioName = line.substring('Scenario Outline:'.length).trim();
        scenarioTags = {...pendingTags};
        pendingTags = {};
        isOutline = true;
        mode = _Mode.scenario;
        continue;
      }

      if (line.startsWith('Scenario:')) {
        flushScenario();
        scenarioName = line.substring('Scenario:'.length).trim();
        scenarioTags = {...pendingTags};
        pendingTags = {};
        isOutline = false;
        mode = _Mode.scenario;
        continue;
      }

      if (line.startsWith('Examples:')) {
        mode = _Mode.examples;
        examples = [];
        examplesHeader = null;
        continue;
      }

      if (mode == _Mode.examples && line.startsWith('|')) {
        final cells = line
            .split('|')
            .skip(1)
            .takeWhile((c) => true)
            .map((c) => c.trim())
            .toList();
        if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
        final header = examplesHeader;
        if (header == null) {
          examplesHeader = cells;
        } else {
          final row = <String, String>{};
          for (var i = 0; i < header.length && i < cells.length; i++) {
            row[header[i]] = cells[i];
          }
          examples!.add(row);
        }
        continue;
      }

      final stepMatch = RegExp(r'^(Given|When|Then|And|But)\s+(.*)$').firstMatch(line);
      if (stepMatch != null) {
        final step = GherkinStep(stepMatch.group(1)!, stepMatch.group(2)!.trim());
        if (mode == _Mode.background) {
          background.add(step);
        } else if (mode == _Mode.scenario) {
          scenarioSteps.add(step);
        }
        continue;
      }
      // 其他說明文字：略過。
    }
    flushScenario();

    return GherkinDocument(
      featureName: featureName,
      featureTags: featureTags,
      background: background,
      scenarios: scenarios,
    );
  }
}

enum _Mode { header, background, scenario, examples }

typedef GherkinStepHandler = void Function(Map<String, String> params);

/// 未匹配到任何句型綁定（dsl.md §5：新句型需先登記）。
class GherkinStepNotBound implements Exception {
  const GherkinStepNotBound(this.stepText);
  final String stepText;

  @override
  String toString() =>
      'GherkinStepNotBound: 未登記的步驟句型「$stepText」（請先登記 specs/plan/tests/dsl.md）';
}

class GherkinBinding {
  const GherkinBinding(this.regex, this.names, this.handler);
  final RegExp regex;
  final List<String> names; // 具名群組對應之參數名（依出現順序）
  final GherkinStepHandler handler;
}

class GherkinRunner {
  final List<GherkinBinding> _bindings = [];
  final List<String> log = [];

  /// 登記句型：`已建立帳戶「{name}」(餘額 {amount})` → 具名群組 regex。
  void on(String pattern, GherkinStepHandler handler) {
    final names = <String>[];
    final buf = StringBuffer();
    for (final m in RegExp(r'\{(\w+)\}').allMatches(pattern)) {
      names.add(m.group(1)!);
    }
    buf.write(
      pattern.replaceAllMapped(
          RegExp(r'\{(\w+)\}'), (m) => '(?<${m.group(1)}>.+?)'),
    );
    _bindings.add(GherkinBinding(RegExp(buf.toString()), names, handler));
  }

  /// 執行文件；回傳已執行情境數（Outline 逐列展開計一次）。
  Future<int> run(
    GherkinDocument doc, {
    bool Function(Set<String> tags)? tagFilter,
  }) async {
    var executed = 0;
    for (final sc in doc.scenarios) {
      final tags = {...doc.featureTags, ...sc.tags};
      if (tagFilter != null && !tagFilter(tags)) continue;

      if (sc.isOutline && sc.examples != null) {
        for (final row in sc.examples!) {
          await _execute([...doc.background, ...sc.steps], row, tags, sc.name);
          executed++;
        }
      } else {
        await _execute([...doc.background, ...sc.steps], const {}, tags, sc.name);
        executed++;
      }
    }
    return executed;
  }

  Future<void> _execute(
    List<GherkinStep> steps,
    Map<String, String> vars,
    Set<String> tags,
    String scenarioName,
  ) async {
    for (final step in steps) {
      var text = step.text;
      for (final entry in vars.entries) {
        text = text.replaceAll('<${entry.key}>', entry.value);
      }
      var bound = false;
      for (final binding in _bindings) {
        final m = binding.regex.firstMatch(text);
        if (m != null) {
          final params = <String, String>{};
          for (var i = 0; i < binding.names.length; i++) {
            params[binding.names[i]] = m.group(i + 1) ?? '';
          }
          binding.handler(params);
          log.add('$scenarioName · ${step.keyword} $text');
          bound = true;
          break;
        }
      }
      if (!bound) {
        throw GherkinStepNotBound(text);
      }
    }
  }
}
