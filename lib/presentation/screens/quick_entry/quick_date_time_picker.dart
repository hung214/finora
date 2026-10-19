import 'package:flutter/material.dart';

/// 快記時間選擇器（FR-Q8，S1.5）：bottom sheet 形式，**不離開快記頁**。
///
/// M1 精簡版：日期以 CalendarDatePicker 選取、時分沿用 initial 的時分；
/// 完整日期＋時間複合滾輪隨 UI 打磨迭代（驗收僅要求選擇器開於原頁）。
class QuickDateTimePicker extends StatefulWidget {
  const QuickDateTimePicker({
    super.key,
    required this.initial,
    required this.onSelected,
  });

  final DateTime initial;
  final void Function(DateTime) onSelected;

  @override
  State<QuickDateTimePicker> createState() => _QuickDateTimePickerState();
}

class _QuickDateTimePickerState extends State<QuickDateTimePicker> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('選擇日期與時間',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 320,
            child: CalendarDatePicker(
              initialDate: widget.initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2032, 12, 31),
              onDateChanged: (d) => _selected = DateTime(
                d.year,
                d.month,
                d.day,
                widget.initial.hour,
                widget.initial.minute,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSelected(_selected);
              },
              child: const Text('確定'),
            ),
          ),
        ],
      ),
    );
  }
}
