import 'package:flutter/material.dart';
import 'package:expressions/expressions.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // We keep tokens so we can safely build and parse: [12, +, 3, *, 4]
  final List<String> _tokens = [];
  String _accumulator = ''; // full expression, may end with '= result'
  String _resultText = '';  // live result or error text

  // Layout labels
  static const List<List<String>> _keys = [
    ['7', '8', '9', '/'],
    ['4', '5', '6', '*'],
    ['1', '2', '3', '-'],
    ['C', '0', '=', '+'],
  ];

  bool get _justEvaluated => _accumulator.contains('='); // last press was '='

  void _onKey(String k) {
    if (k == 'C') {
      _clear();
      return;
    }
    if (k == '=') {
      _finalEvaluate();
      return;
    }
    // If last action was '=', start a new calc when a digit or operator arrives
    if (_justEvaluated) {
      _accumulator = '';
      _tokens.clear();
      _resultText = '';
    }

    if (_isDigit(k)) {
      _appendDigit(k);
    } else {
      _appendOperator(k);
    }

    _updateAccumulator();
    _liveEvaluate();
  }

  void _appendDigit(String d) {
    if (_tokens.isEmpty || _isOperator(_tokens.last)) {
      _tokens.add(d); // start new number
    } else {
      // extend current number
      final combined = (_tokens.last + d);
      // avoid numbers like 00012
      _tokens[_tokens.length - 1] =
          combined.length > 1 && combined.startsWith('0')
              ? _stripLeadingZeros(combined)
              : combined;
    }
  }

  void _appendOperator(String op) {
    if (_tokens.isEmpty) {
      // allow leading minus as a negative sign
      if (op == '-') {
        _tokens.add('0');
        _tokens.add('-');
      }
      return;
    }
    if (_isOperator(_tokens.last)) {
      // Replace the last operator if user taps operators twice
      _tokens[_tokens.length - 1] = op;
    } else {
      _tokens.add(op);
    }
  }

  void _updateAccumulator() {
    _accumulator = _tokens.join(' ');
  }

  void _liveEvaluate() {
    if (_tokens.isEmpty) {
      setState(() => _resultText = '');
      return;
    }
    // Only try when last token is a number
    if (_isOperator(_tokens.last)) {
      setState(() => _resultText = '');
      return;
    }
    final exprStr = _tokens.join(' ');
    final res = _safeEval(exprStr);
    setState(() => _resultText = res);
  }

  void _finalEvaluate() {
    if (_tokens.isEmpty || _isOperator(_tokens.last)) {
      // nothing to do
      return;
    }
    final exprStr = _tokens.join(' ');
    final res = _safeEval(exprStr);
    setState(() {
      _accumulator = '$exprStr = $res';
      _resultText = res;
    });
  }

  String _safeEval(String exprStr) {
    try {
      final expr = Expression.parse(exprStr);
      final evaluator = const ExpressionEvaluator();
      final num? value = evaluator.eval(expr, const {}) as num?;
      if (value == null) return 'Error';
      final double d = value.toDouble();
      if (d.isNaN || d.isInfinite) return 'Error';
      // Trim trailing zeros
      final fixed = d.toStringAsFixed(10);
      return _trimNumber(fixed);
    } catch (_) {
      // Try to detect divide by zero in a simple way
      if (exprStr.contains('/ 0')) return 'Error: divide by zero';
      return 'Error';
    }
  }

  String _trimNumber(String s) {
    // 14.0000000000 -> 14, 14.2300000000 -> 14.23
    var out = s;
    while (out.contains('.') && (out.endsWith('0') || out.endsWith('.'))) {
      out = out.endsWith('.') ? out.substring(0, out.length - 1) : out.substring(0, out.length - 1);
      if (!out.contains('.')) break;
    }
    return out;
  }

  String _stripLeadingZeros(String s) {
    final stripped = s.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
    }

  bool _isDigit(String k) => RegExp(r'^[0-9]$').hasMatch(k);
  bool _isOperator(String k) => k == '+' || k == '-' || k == '*' || k == '/';

  void _clear() {
    setState(() {
      _tokens.clear();
      _accumulator = '';
      _resultText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nathan Lannon'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            children: [
                // Display
                Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                    Text(
                        _accumulator.isEmpty ? '0' : _accumulator,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        _resultText.isEmpty ? '' : _resultText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _resultText.startsWith('Error')
                            ? Colors.red
                            : scheme.primary,
                        ),
                    ),
                    ],
                ),
                ),
                const SizedBox(height: 16),
                // Keypad
                Expanded(
                child: LayoutBuilder(
                    builder: (context, c) {
                        final rows = _keys.length;
                        const rowGap = 12.0; // vertical gap between rows (matches the Padding in each row)
                        final sizeByWidth  = (c.maxWidth - 24) / 4;                    // 24 ~= left+right breathing room
                        final sizeByHeight = (c.maxHeight - rowGap * (rows - 1)) / rows;
                        final btnSize = sizeByHeight < sizeByWidth ? sizeByHeight : sizeByWidth;return Column(
                        children: _keys.map((row) {
                        return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: row.map((label) {
                                final isOp = _isOperator(label) || label == '=' || label == 'C';
                                return _CalcButton(
                                label: label,
                                size: btnSize,
                                onTap: () => _onKey(label),
                                isPrimary: label == '=',
                                isDanger: label == 'C',
                                isOp: isOp,
                                );
                            }).toList(),
                            ),
                        );
                        }).toList(),
                    );
                    },
                ),
                ),
                const SizedBox(height: 8),
                const Text(
                'Tip: expressions follow normal order of operations.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
            ),
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final double size;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;
  final bool isOp;

  const _CalcButton({
    required this.label,
    required this.size,
    required this.onTap,
    this.isPrimary = false,
    this.isDanger = false,
    this.isOp = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isPrimary
        ? scheme.primary
        : isDanger
            ? Colors.red
            : isOp
                ? scheme.secondaryContainer
                : scheme.surfaceVariant;
    final fg = isPrimary ? scheme.onPrimary : null;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
