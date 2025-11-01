import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/note.dart';

class SummaryPage extends StatefulWidget {
  final List<Note> notes;
  const SummaryPage({super.key, required this.notes});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late DateTime _focusedDay;
  List<Note> _notesInFocusedYear = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _filterNotesForFocusedYear();
  }

  void _filterNotesForFocusedYear() {
    _notesInFocusedYear = widget.notes.where((n) => n.createdAt.year == _focusedDay.year).toList();
  }

  Map<int, int> _calculateMonthlyNoteCounts() {
    final counts = {for (var i = 1; i <= 12; i++) i: 0};
    for (final n in _notesInFocusedYear) {
      counts[n.createdAt.month] = (counts[n.createdAt.month] ?? 0) + 1;
    }
    return counts;
  }

  List<Note> _getNotesForDay(DateTime day) {
    return widget.notes.where((n) => n.createdAt.year == day.year && n.createdAt.month == day.month && n.createdAt.day == day.day).toList();
  }

  @override
  Widget build(BuildContext context) {
    final monthlyCounts = _calculateMonthlyNoteCounts();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryCard(monthlyCounts),
            const SizedBox(height: 24),
            _buildCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<int, int> monthlyCounts) {
    final totalNotesInYear = _notesInFocusedYear.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  totalNotesInYear.toString(),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('This year', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(width: 20),
              Expanded(child: SizedBox(height: 100, child: _buildBarChart(monthlyCounts))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<int, int> monthlyCounts) {
    final maxValue = monthlyCounts.values.fold(0, (max, v) => v > max ? v : max).toDouble();
    final primaryColor = Theme.of(context).colorScheme.primary;
    return BarChart(
      BarChartData(
        maxY: maxValue == 0 ? 5 : maxValue,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 16,
              getTitlesWidget: (value, meta) {
                const monthInitials = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                final idx = value.toInt();
                if (idx < 1 || idx > 12) return const SizedBox.shrink();
                return Text(monthInitials[idx - 1], style: Theme.of(context).textTheme.bodySmall);
              },
            ),
          ),
        ),
        barGroups: List.generate(12, (index) {
          final month = index + 1;
          return BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: (monthlyCounts[month] ?? 0).toDouble(),
                color: primaryColor,
                width: 6,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCalendar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.2)),
          ),
          child: TableCalendar<Note>(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: CalendarFormat.month,
            eventLoader: _getNotesForDay,
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _filterNotesForFocusedYear();
              });
            },
            headerStyle: HeaderStyle(
              titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
              titleTextStyle: Theme.of(context).textTheme.titleMedium!,
              formatButtonVisible: false,
              leftChevronIcon: const Icon(Icons.chevron_left),
              rightChevronIcon: const Icon(Icons.chevron_right),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 5,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }
}





