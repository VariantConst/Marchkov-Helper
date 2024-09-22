import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import '../../widgets/bus_route_card.dart';
import 'package:intl/intl.dart';

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  List<dynamic> _busList = []; // 原始班车列表
  List<dynamic> _filteredBusList = []; // 过滤后的班车列表
  bool _isLoading = true;
  String _errorMessage = '';
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;
  late PageController _calendarController;
  late PageController _mainPageController;
  int _currentPage = 0; // 添加这行来定义 _currentPage

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDates = _getWeekDates();
    _loadReservationData();
    _calendarController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.2,
    );
    _mainPageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _mainPageController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDates() {
    DateTime now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index)));
  }

  void _filterBusList() {
    setState(() {
      _filteredBusList = _busList.where((bus) {
        final busDate = DateTime.parse(bus['abscissa'].split(' ')[0]);
        return busDate.year == _selectedDate.year &&
            busDate.month == _selectedDate.month &&
            busDate.day == _selectedDate.day;
      }).toList();
    });
  }

  Future<void> _loadReservationData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final today = DateTime.now();
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 6)).toIso8601String().split('T')[0],
      ];

      final allBuses = await reservationService.getAllBuses(dateStrings);

      setState(() {
        _busList = allBuses;
        _filterBusList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendar(), // 将日历移到外部
            Expanded(
              child: PageView.builder(
                controller: _mainPageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                    _selectedDate = _weekDates[page];
                    _filterBusList();
                  });
                  _calendarController.animateToPage(
                    page,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                itemCount: _weekDates.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 已移除 _buildCalendar()
                        SizedBox(height: 20),
                        Expanded(
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _errorMessage.isNotEmpty
                                  ? Center(child: Text(_errorMessage))
                                  : _filteredBusList.isEmpty
                                      ? Center(child: Text('暂无班车信息'))
                                      : _buildBusList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return SizedBox(
      height: 100,
      child: PageView.builder(
        controller: _calendarController,
        onPageChanged: (int page) {
          _mainPageController.animateToPage(
            page,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = index == _currentPage;
          final pageOffset = (index - _currentPage).abs();
          final scale = 1 - (pageOffset * 0.1).clamp(0.0, 0.3);
          final opacity = 1 - (pageOffset * 0.3).clamp(0.0, 0.7);

          return GestureDetector(
            onTap: () {
              _calendarController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: isSelected ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusList() {
    final toChangping = _filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      final indexYan = name.indexOf('燕');
      final indexXin = name.indexOf('新');
      return indexYan != -1 && indexXin != -1 && indexYan < indexXin;
    }).toList();

    final toYanyuan = _filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      final indexYan = name.indexOf('燕');
      final indexXin = name.indexOf('新');
      return indexYan != -1 && indexXin != -1 && indexXin < indexYan;
    }).toList();

    return ListView(
      children: [
        _buildBusCard('去昌平', toChangping, Colors.blue[100]!),
        SizedBox(height: 20),
        _buildBusCard('去燕园', toYanyuan, Colors.green[100]!),
      ],
    );
  }

  Widget _buildBusCard(String title, List<dynamic> buses, Color cardColor) {
    // 按发车时间排序
    buses.sort((a, b) => a['yaxis'].compareTo(b['yaxis']));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2, // 调整宽高比，使卡片更扁平
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: buses.length,
              itemBuilder: (context, index) {
                return BusRouteCard(
                  busData: buses[index],
                  onTap: () => _showBusDetails(buses[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBusDetails(Map<String, dynamic> busData) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: BusRouteDetails(busData: busData),
        );
      },
    );
  }
}
