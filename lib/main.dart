import 'package:flutter/material.dart';
import 'package:greenwarrior/pages/Qr_Scan/Qr_scan_screen.dart';
import 'package:greenwarrior/pages/Qr_Scan/bin_collection.dart';
import 'package:greenwarrior/pages/attendance/attendancePage.dart';
import 'package:greenwarrior/pages/attendance/manual_attendance.dart';
import 'package:greenwarrior/pages/attendance/pending_attendance.dart';
import 'package:greenwarrior/pages/employee/employee_page.dart';
import 'package:greenwarrior/pages/fuel_log/fuel_log_list.dart';
import 'package:greenwarrior/pages/fuel_station/fuel_station_list.dart';
import 'package:greenwarrior/pages/job_cards/job_card_list.dart';
import 'package:greenwarrior/pages/Device/devicesPage.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:greenwarrior/pages/operation/operation_page.dart';
import 'package:greenwarrior/pages/routes/routes_list.dart';
import 'package:greenwarrior/pages/shifts/shift_list.dart';
import 'package:greenwarrior/pages/staff_pages/staff_list.dart';
import 'package:greenwarrior/pages/ward/ward_list.dart';
import 'package:greenwarrior/pages/zones/zones_list.dart';
import 'package:greenwarrior/theme/dark_mode.dart';

import 'package:greenwarrior/auth/auth_page.dart';
import 'package:greenwarrior/pages/vehicles/vehicles_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR2',
      theme: darkMode,
      debugShowCheckedModeBanner: false,
      home: const AuthPage(),
      routes: {
        "/login_page": (context) => const LoginPage(),
        "/staff_list": (context) => const StaffList(),
        "/vehicles_list": (context) => const VehiclesList(),
        "/zones_list": (context) => const ZonesList(),
        "/wards_list": (context) => const WardList(),
        "/routes_list": (context) => const RoutesList(),
        "/shift_list": (context) => const ShiftListPage(),
        "/fuel_log_list": (context) => const FuelLogList(),
        "/job_card_list": (context) => const JobCardList(),
        "/fuel_station_list": (context) => const FuelStationList(),
        "/attendance_page": (context) => const AttendancePage(),
        "/manual_page": (context) => const ManualAttendance(),
        "/pending_page": (context) => const PendingAttendance(),
        "/device_page": (context) => const DeviceStatusPage(),
        "/operation_page": (context) => const OperationPage(),
        "/employee_page": (context) => const EmployeeDetailsPage(),
        "/qr_scanner": (context) => QRScannerScreen(),
        "/bin_collection": (context) => const BinCollectionScreen(),
      },
    );
  }
}
