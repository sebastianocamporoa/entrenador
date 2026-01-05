import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyScheduleBar extends StatefulWidget {
  /// Lista de fechas (Strings ISO 'yyyy-MM-dd') que tienen entreno
  final List<String> workoutDates;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WeeklyScheduleBar({
    super.key,
    required this.workoutDates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeeklyScheduleBar> createState() => _WeeklyScheduleBarState();
}

class _WeeklyScheduleBarState extends State<WeeklyScheduleBar> {
  late ScrollController _scrollController;
  final int _daysBack = 15; // Días hacia atrás para mostrar
  final int _daysForward = 15; // Días hacia adelante para mostrar
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    // Generamos la lista de fechas (Ej: 30 días en total)
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _daysBack));
    _dates = List.generate(
      _daysBack + _daysForward + 1,
      (index) => start.add(Duration(days: index)),
    );

    // Calculamos para que el scroll inicie centrado en HOY (aprox)
    // Cada item mide aprox 60px de ancho
    _scrollController = ScrollController(
      initialScrollOffset:
          (_daysBack * 58.0) -
          (MediaQueryData.fromView(WidgetsBinding.instance.window).size.width /
              2) +
          30,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85, // Altura fija para la barra
      color: const Color(0xFF1C1C1E),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];

          // Formatos
          final dayName = DateFormat(
            'E',
            'es_ES',
          ).format(date).toUpperCase().substring(0, 1); // L, M, X...
          final dayNumber = date.day.toString();

          // Comparaciones
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, DateTime.now());

          // Convertimos a string yyyy-MM-dd para buscar en la lista de entrenos
          final dateIso = DateFormat('yyyy-MM-dd').format(date);
          final hasWorkout = widget.workoutDates.contains(dateIso);

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: Container(
              width: 50, // Ancho de cada día
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors
                  .transparent, // Para que el tap funcione en todo el área
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nombre del día
                  Text(
                    dayName,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFBF5AF2) : Colors.grey,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Círculo del número
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(
                              0xFFBF5AF2,
                            ) // Fondo morado si seleccionado
                          : (isToday
                                ? const Color(0xFF2C2C2E)
                                : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? null
                          : (hasWorkout
                                ? Border.all(
                                    color: Colors.white38,
                                    width: 1,
                                  ) // Borde si hay entreno
                                : null),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayNumber,
                      style: TextStyle(
                        color: isSelected || isToday
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Puntito indicador
                  if (hasWorkout && !isSelected)
                    const CircleAvatar(
                      radius: 2,
                      backgroundColor: Color(0xFFBF5AF2),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
