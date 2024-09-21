import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'dart:convert';
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
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDates = _getWeekDates();
    _loadReservationData();
    _currentPage = 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.2,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
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

      final responses = await Future.wait(
        dateStrings.map((dateString) =>
            reservationService.fetchReservationData(dateString)),
      );

      List<dynamic> allBuses = [];

      for (var response in responses) {
        final data = json.decode(response);

        if (data['e'] == 0) {
          List<dynamic> list = data['d']['list'];

          for (var bus in list) {
            var busId = bus['id'];
            var table = bus['table'];
            for (var key in table.keys) {
              var timeSlots = table[key];
              for (var slot in timeSlots) {
                if (slot['row']['margin'] > 0) {
                  String dateTimeString = slot['abscissa'];
                  DateTime busDateTime = DateTime.parse(dateTimeString);

                  if (busDateTime.isAfter(DateTime.now()) &&
                      busDateTime
                          .isBefore(DateTime.now().add(Duration(days: 7)))) {
                    Map<String, dynamic> busInfo = {
                      'route_name': bus['name'],
                      'bus_id': busId,
                      'abscissa': slot['abscissa'],
                      'yaxis': slot['yaxis'],
                      'row': slot['row'],
                      'time_id': slot['time_id'],
                      'status': slot['row']['status'],
                    };
                    final name = busInfo['route_name'] ?? '';
                    final indexYan = name.indexOf('燕');
                    final indexXin = name.indexOf('新');
                    if (indexYan != -1 && indexXin != -1) {
                      allBuses.add(busInfo);
                    }
                  }
                }
              }
            }
          }
        } else {
          throw Exception(data['m']);
        }
      }

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
      appBar: AppBar(
        title: Text('预约'),
      ),
      body: Column(
        children: [
          _buildCalendar(),
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
  }

  Widget _buildCalendar() {
    return SizedBox(
      height: 80,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
            _selectedDate = _weekDates[page];
            _filterBusList();
          });
        },
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = index == _currentPage;

          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300]!,
                width: 2,
              ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ],
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
        _buildBusSection('去昌平', toChangping),
        _buildBusSection('去燕园', toYanyuan),
      ],
    );
  }

  Widget _buildBusSection(String title, List<dynamic> buses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: buses.map<Widget>((busData) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 40) / 4,
              child: BusRouteCard(
                busData: busData,
                onTap: () => _showBusDetails(busData),
              ),
            );
          }).toList(),
        ),
      ],
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
