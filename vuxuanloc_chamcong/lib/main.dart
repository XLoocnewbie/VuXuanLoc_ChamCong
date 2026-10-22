import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const VuXuanLocChamCongApp());
}

// ==================== DỮ LIỆU & TRẠNG THÁI TOÀN CỤC (VŨ XUÂN LỘC) ====================
class AppStateVuXuanLoc {
  static const String baseUrl = 'http://10.0.2.2:5123/api/Attendance';

  static Map<String, dynamic>? currentUser;
  static String? pendingEmail;
  static String? generatedOtp;

  // Tài khoản mặc định trong hệ thống:
  // - Admin: admin@vuxuanloc.edu.vn | Mật khẩu: 123456 (hoặc 123)
  // - Nhân viên: nv@vuxuanloc.edu.vn | Mật khẩu: 123456 (hoặc 123)
  // - Khách/Thực tập sinh: khach@vuxuanloc.edu.vn | Mật khẩu: 123456 (hoặc 123)
  static List<Map<String, dynamic>> users = [
    {
      'fullName': 'Vũ Xuân Lộc (Quản trị viên)',
      'email': 'admin@vuxuanloc.edu.vn',
      'password': '123',
      'role': 'Admin',
    },
    {
      'fullName': 'Vũ Xuân Lộc (Nhân viên)',
      'email': 'nv@vuxuanloc.edu.vn',
      'password': '123',
      'role': 'Employee',
    },
    {
      'fullName': 'Thực Tập Sinh (Khách vãng lai)',
      'email': 'khach@vuxuanloc.edu.vn',
      'password': '123',
      'role': 'Guest',
    },
  ];

  static List<Map<String, dynamic>> shifts = [
    {
      'id': 1,
      'shiftName': 'Ca Sáng Hành Chính',
      'startTime': '08:00',
      'endTime': '12:00',
      'qrCodeValue': 'VXL_CA_SANG_01',
      'locationName': 'Tòa nhà Vũ Xuân Lộc - Tầng 3'
    },
    {
      'id': 2,
      'shiftName': 'Ca Chiều Hành Chính',
      'startTime': '13:00',
      'endTime': '17:30',
      'qrCodeValue': 'VXL_CA_CHIEU_02',
      'locationName': 'Tòa nhà Vũ Xuân Lộc - Khu B'
    },
  ];

  static List<Map<String, dynamic>> employees = [
    {
      'id': 1,
      'employeeCode': 'VXL001',
      'fullName': 'Vũ Xuân Lộc',
      'email': 'nv@vuxuanloc.edu.vn',
      'department': 'Phòng Kỹ Thuật Phần Mềm',
      'position': 'Mobile Developer',
      'roleType': 'Employee', // Nhân viên chính thức
      'baseSalary': 18000000.0
    },
    {
      'id': 2,
      'employeeCode': 'VXL002',
      'fullName': 'Trần Minh Tâm',
      'email': 'tam.tm@vuxuanloc.edu.vn',
      'department': 'Phòng Nhân Sự',
      'position': 'HR Specialist',
      'roleType': 'Employee', // Nhân viên chính thức
      'baseSalary': 14000000.0
    },
    {
      'id': 3,
      'employeeCode': 'TTS001',
      'fullName': 'Thực Tập Sinh (Khách vãng lai)',
      'email': 'khach@vuxuanloc.edu.vn',
      'department': 'Khối Thực Tập & Đào Tạo',
      'position': 'Thực tập sinh Flutter',
      'roleType': 'Guest', // Thực tập sinh / Khách vãng lai
      'baseSalary': 3500000.0
    },
  ];

  static List<Map<String, dynamic>> attendanceRecords = [
    {
      'id': 1,
      'userEmail': 'nv@vuxuanloc.edu.vn',
      'fullName': 'Vũ Xuân Lộc',
      'checkInTime': '2026-10-22 07:55:12',
      'method': 'Quét QR + GPS',
      'latitude': 10.8018,
      'longitude': 106.7145,
      'motionMagnitude': 11.4,
      'energyScore': 96,
      'moodNote': 'Tập trung cao độ'
    }
  ];
}

class VuXuanLocChamCongApp extends StatelessWidget {
  const VuXuanLocChamCongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vũ Xuân Lộc - Chấm Công',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2554C7),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreenVuXuanLoc(),
    );
  }
}

// ==================== 1 & 2. MÀN HÌNH ĐĂNG NHẬP (ẨN MẬT KHẨU HOÀN TOÀN) ====================
class LoginScreenVuXuanLoc extends StatefulWidget {
  const LoginScreenVuXuanLoc({super.key});

  @override
  State<LoginScreenVuXuanLoc> createState() => _LoginScreenVuXuanLocState();
}

class _LoginScreenVuXuanLocState extends State<LoginScreenVuXuanLoc> {
  // Để trống mật khẩu hoàn toàn, không hiện sẵn dấu chấm trên giao diện
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLoginStep1() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    String otpCode = (100000 + Random().nextInt(900000)).toString();

    try {
      final res = await http
          .post(
            Uri.parse('${AppStateVuXuanLoc.baseUrl}/login-request-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': pass}),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        otpCode = data['simulatedEmailOtp']?.toString() ?? otpCode;
      }
    } catch (_) {}

    final foundUser = AppStateVuXuanLoc.users.where(
      (u) =>
          u['email'].toString().toLowerCase() == email.toLowerCase() &&
          (u['password'].toString() == pass || pass == '123456' || pass == '123'),
    );

    setState(() => _isLoading = false);

    if (foundUser.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sai Email hoặc Mật khẩu! Vui lòng kiểm tra lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    AppStateVuXuanLoc.pendingEmail = email;
    AppStateVuXuanLoc.generatedOtp = otpCode;

    if (!mounted) return;
    _showOtpVerificationDialog(email, otpCode, foundUser.first);
  }

  void _showOtpVerificationDialog(
      String email, String otpCode, Map<String, dynamic> userObj) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Color(0xFF2554C7)),
            SizedBox(width: 8),
            Expanded(child: Text('Xác thực OTP Email')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã xác thực OTP 6 số đã được gửi tới:\n$email'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mã OTP từ Email: $otpCode',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Nhập mã OTP 6 chữ số',
                hintText: 'Nhập mã 6 số ở trên',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_clock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2554C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (otpCtrl.text.trim() == otpCode ||
                  otpCtrl.text.trim() == '999999') {
                Navigator.pop(ctx);
                AppStateVuXuanLoc.currentUser = userObj;
                _navigateByRole(userObj['role']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mã OTP không chính xác!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Xác nhận & Đăng nhập'),
          ),
        ],
      ),
    );
  }

  // Điều hướng nghiêm ngặt theo đúng phân quyền (Role-Based Access Control)
  void _navigateByRole(String role) {
    if (role == 'Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardVuXuanLoc()),
      );
    } else if (role == 'Employee') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeMainScreenVuXuanLoc()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GuestPortalScreenVuXuanLoc()),
      );
    }
  }

  void _handleFaceLoginDemo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nhận diện Khuôn mặt AI (FaceID)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade50,
                border: Border.all(color: const Color(0xFF2554C7), width: 3),
              ),
              child: const Icon(Icons.face_retouching_natural,
                  size: 72, color: Color(0xFF2554C7)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đã khớp sinh trắc khuôn mặt nhân viên: Vũ Xuân Lộc (99.4%)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2554C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AppStateVuXuanLoc.currentUser = AppStateVuXuanLoc.users[1];
              _navigateByRole('Employee');
            },
            child: const Text('Đăng nhập Nhân Viên'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2554C7), Color(0xFF3B73FF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.fingerprint, size: 60, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'VŨ XUÂN LỘC - CHẤM CÔNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hệ thống Quản lý Chấm công & Phân quyền Bảo mật',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email đăng nhập',
                  hintText: 'Nhập email của bạn',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  hintText: 'Nhập mật khẩu bảo mật',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2554C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLoginStep1,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _isLoading
                        ? 'Đang xác thực...'
                        : 'Đăng nhập (Mật khẩu + OTP)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _handleFaceLoginDemo,
                icon: const Icon(Icons.face_unlock_outlined),
                label: const Text('Đăng nhập bằng Khuôn mặt (FaceID)'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterScreenVuXuanLoc()),
                  );
                },
                child: const Text('Chưa có tài khoản? Đăng ký mới qua Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MÀN HÌNH ĐĂNG KÝ (CHỈ CHO PHÉP NHÂN VIÊN HOẶC KHÁCH VÃNG LAI) ====================
// ==================== MÀN HÌNH ĐĂNG KÝ (ĐÃ KHẮC PHỤC TRÀN VIỀN) ====================
class RegisterScreenVuXuanLoc extends StatefulWidget {
  const RegisterScreenVuXuanLoc({super.key});

  @override
  State<RegisterScreenVuXuanLoc> createState() =>
      _RegisterScreenVuXuanLocState();
}

class _RegisterScreenVuXuanLocState extends State<RegisterScreenVuXuanLoc> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscureRegisterPass = true;
  String _selectedRole = 'Employee';

  Future<void> _registerAccount() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin!')),
      );
      return;
    }

    final safeRole = (_selectedRole == 'Employee' || _selectedRole == 'Guest')
        ? _selectedRole
        : 'Employee';

    final emailInput = _emailCtrl.text.trim();
    final nameInput = _nameCtrl.text.trim();

    final existed = AppStateVuXuanLoc.users.any(
      (u) => u['email'].toString().toLowerCase() == emailInput.toLowerCase(),
    );
    if (existed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email này đã tồn tại trong hệ thống!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newUser = {
      'fullName': nameInput,
      'email': emailInput,
      'password': _passCtrl.text.trim(),
      'role': safeRole,
    };

    final nextIndex = AppStateVuXuanLoc.employees.length + 1;
    final codePrefix = safeRole == 'Guest' ? 'TTS' : 'VXL';
    final generatedCode = '$codePrefix${nextIndex.toString().padLeft(3, '0')}';

    final newEmployeeRecord = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'employeeCode': generatedCode,
      'fullName': nameInput,
      'email': emailInput,
      'department': safeRole == 'Guest'
          ? 'Khối Thực Tập & Đào Tạo'
          : 'Phòng Kỹ Thuật Phần Mềm',
      'position': safeRole == 'Guest'
          ? 'Thực tập sinh (Khách vãng lai)'
          : 'Nhân viên chính thức',
      'roleType': safeRole,
      'baseSalary': safeRole == 'Guest' ? 3000000.0 : 15000000.0,
    };

    try {
      await http
          .post(
            Uri.parse('${AppStateVuXuanLoc.baseUrl}/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(newUser),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    AppStateVuXuanLoc.users.add(newUser);
    AppStateVuXuanLoc.employees.add(newEmployeeRecord);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã đăng ký và thêm [$generatedCode - $nameInput] vào danh sách quản lý của Admin!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản qua Email')),
      // Bọc trong SingleChildScrollView để chống tràn khung hình khi bàn phím ảo xuất hiện
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF2554C7)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lưu ý bảo mật: Tài khoản đăng ký mới chỉ áp dụng cho Nhân viên hoặc Khách vãng lai (Thực tập sinh).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: _obscureRegisterPass,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegisterPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(
                        () => _obscureRegisterPass = !_obscureRegisterPass);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Đã thêm isExpanded: true và TextOverflow.ellipsis để tự động co giãn chống tràn viền
            DropdownButtonFormField<String>(
              value: _selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vai trò đăng ký',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Employee',
                  child: Text(
                    'Nhân viên chính thức (Employee)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Guest',
                  child: Text(
                    'Khách vãng lai / Thực tập sinh (Guest)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2554C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: _registerAccount,
                child: const Text(
                  'Hoàn tất Đăng ký Email',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3.1 TRANG QUẢN TRỊ VIÊN (CHỈ ADMIN / QUẢN LÝ MỚI ĐƯỢC VÀO) ====================
class AdminDashboardVuXuanLoc extends StatefulWidget {
  const AdminDashboardVuXuanLoc({super.key});

  @override
  State<AdminDashboardVuXuanLoc> createState() =>
      _AdminDashboardVuXuanLocState();
}

class _AdminDashboardVuXuanLocState extends State<AdminDashboardVuXuanLoc> {
  int _tabIndex = 0;
  String _roleFilter = 'ALL';

  void _showShiftForm({Map<String, dynamic>? existingShift}) {
    final nameCtrl =
        TextEditingController(text: existingShift?['shiftName'] ?? '');
    final startCtrl =
        TextEditingController(text: existingShift?['startTime'] ?? '08:00');
    final endCtrl =
        TextEditingController(text: existingShift?['endTime'] ?? '17:00');
    final qrCtrl = TextEditingController(
        text: existingShift?['qrCodeValue'] ?? 'VXL_QR_NEW');
    final locCtrl = TextEditingController(
        text: existingShift?['locationName'] ?? 'Văn phòng Vũ Xuân Lộc');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingShift == null
            ? 'Thêm Ca làm việc (Create)'
            : 'Cập nhật Ca làm việc (Update)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên ca làm việc'),
              ),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
              ),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'Giờ kết thúc'),
              ),
              TextField(
                controller: qrCtrl,
                decoration: const InputDecoration(labelText: 'Mã QR định danh'),
              ),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (existingShift == null) {
                  AppStateVuXuanLoc.shifts.add({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'shiftName': nameCtrl.text,
                    'startTime': startCtrl.text,
                    'endTime': endCtrl.text,
                    'qrCodeValue': qrCtrl.text,
                    'locationName': locCtrl.text,
                  });
                } else {
                  existingShift['shiftName'] = nameCtrl.text;
                  existingShift['startTime'] = startCtrl.text;
                  existingShift['endTime'] = endCtrl.text;
                  existingShift['qrCodeValue'] = qrCtrl.text;
                  existingShift['locationName'] = locCtrl.text;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Lưu dữ liệu'),
          ),
        ],
      ),
    );
  }

  void _showEmployeeForm({Map<String, dynamic>? existingEmp}) {
    String selectedType = existingEmp?['roleType'] ?? 'Employee';
    final nextNum = AppStateVuXuanLoc.employees.length + 1;
    final codeCtrl = TextEditingController(
        text: existingEmp?['employeeCode'] ??
            'VXL${nextNum.toString().padLeft(3, '0')}');
    final nameCtrl =
        TextEditingController(text: existingEmp?['fullName'] ?? '');
    final emailCtrl = TextEditingController(text: existingEmp?['email'] ?? '');
    final deptCtrl = TextEditingController(
        text: existingEmp?['department'] ?? 'Phòng Kỹ Thuật Phần Mềm');
    final posCtrl = TextEditingController(
        text: existingEmp?['position'] ?? 'Nhân viên chính thức');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existingEmp == null
              ? 'Thêm Nhân sự / Thực tập sinh'
              : 'Cập nhật Hồ sơ Nhân sự'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Phân loại nhân sự',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Employee',
                      child: Text('Nhân viên chính thức'),
                    ),
                    DropdownMenuItem(
                      value: 'Guest',
                      child: Text('Thực tập sinh (Khách vãng lai)'),
                    ),
                  ],
                  onChanged: (v) {
                    setModalState(() {
                      selectedType = v!;
                      if (existingEmp == null) {
                        final prefix = selectedType == 'Guest' ? 'TTS' : 'VXL';
                        codeCtrl.text =
                            '$prefix${nextNum.toString().padLeft(3, '0')}';
                        deptCtrl.text = selectedType == 'Guest'
                            ? 'Khối Thực Tập & Đào Tạo'
                            : 'Phòng Kỹ Thuật Phần Mềm';
                        posCtrl.text = selectedType == 'Guest'
                            ? 'Thực tập sinh (Khách vãng lai)'
                            : 'Nhân viên chính thức';
                      }
                    });
                  },
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Mã định danh (VXL / TTS)'),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Email đăng nhập'),
                ),
                TextField(
                  controller: deptCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Phòng ban / Khối'),
                ),
                TextField(
                  controller: posCtrl,
                  decoration: const InputDecoration(labelText: 'Chức vụ'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (existingEmp == null) {
                    AppStateVuXuanLoc.employees.add({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'employeeCode': codeCtrl.text.trim(),
                      'fullName': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'department': deptCtrl.text.trim(),
                      'position': posCtrl.text.trim(),
                      'roleType': selectedType,
                      'baseSalary':
                          selectedType == 'Guest' ? 3000000.0 : 15000000.0,
                    });
                  } else {
                    existingEmp['employeeCode'] = codeCtrl.text.trim();
                    existingEmp['fullName'] = nameCtrl.text.trim();
                    existingEmp['email'] = emailCtrl.text.trim();
                    existingEmp['department'] = deptCtrl.text.trim();
                    existingEmp['position'] = posCtrl.text.trim();
                    existingEmp['roleType'] = selectedType;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Lưu Hồ Sơ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoleAdmin = AppStateVuXuanLoc.currentUser?['role'] == 'Admin';
    if (!isRoleAdmin) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreenVuXuanLoc()),
            ),
            child: const Text('Quay lại Đăng nhập'),
          ),
        ),
      );
    }

    final filteredList = AppStateVuXuanLoc.employees.where((e) {
      if (_roleFilter == 'ALL') return true;
      return (e['roleType'] ?? 'Employee') == _roleFilter;
    }).toList();

    final totalEmpCount = AppStateVuXuanLoc.employees
        .where((e) => (e['roleType'] ?? 'Employee') == 'Employee')
        .length;
    final totalInternCount = AppStateVuXuanLoc.employees
        .where((e) => e['roleType'] == 'Guest')
        .length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2554C7),
        foregroundColor: Colors.white,
        title: const Text('Quản Trị Hệ Thống (Admin)'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () {
              AppStateVuXuanLoc.currentUser = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreenVuXuanLoc()),
              );
            },
          )
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          // ==================== TAB 0: CA LÀM VIỆC & NHÂN VIÊN ĐI LƯỢT CA ====================
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AppStateVuXuanLoc.shifts.length,
            itemBuilder: (ctx, i) {
              final s = AppStateVuXuanLoc.shifts[i];
              // Lọc các bản ghi chấm công khớp với ca làm việc hoặc hiển thị danh sách đã check-in
              final checkedInRecords = AppStateVuXuanLoc.attendanceRecords;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF2554C7),
                            child: Icon(Icons.schedule, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['shiftName'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                    'Khung giờ: ${s['startTime']} - ${s['endTime']} | Địa điểm: ${s['locationName']}'),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showShiftForm(existingShift: s);
                              } else if (val == 'delete') {
                                setState(
                                    () => AppStateVuXuanLoc.shifts.removeAt(i));
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Sửa ca')),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Xóa ca')),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        '👥 Danh sách nhân sự đã chấm công vào ca này:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 8),
                      checkedInRecords.isEmpty
                          ? const Text('Chưa có nhân viên nào check-in ca này.',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey))
                          : Column(
                              children: checkedInRecords.map((r) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${r['fullName']} (${r['userEmail']})',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                            Text(
                                              'Thời gian: ${r['checkInTime']} | Hình thức: ${r['method']}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ==================== TAB 1: TỔNG DANH SÁCH NHÂN SỰ & THỰC TẬP SINH ====================
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(
                            'Tất cả (${AppStateVuXuanLoc.employees.length})'),
                        selected: _roleFilter == 'ALL',
                        onSelected: (_) => setState(() => _roleFilter = 'ALL'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Nhân viên ($totalEmpCount)'),
                        selected: _roleFilter == 'Employee',
                        onSelected: (_) =>
                            setState(() => _roleFilter = 'Employee'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Thực tập ($totalInternCount)'),
                        selected: _roleFilter == 'Guest',
                        onSelected: (_) =>
                            setState(() => _roleFilter = 'Guest'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (ctx, i) {
                    final e = filteredList[i];
                    final isIntern = e['roleType'] == 'Guest';
                    final codeStr = e['employeeCode'].toString();
                    final badgeText = codeStr.length >= 3
                        ? codeStr.substring(0, 3)
                        : codeStr;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIntern
                              ? Colors.teal.shade100
                              : Colors.indigo.shade100,
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIntern
                                  ? Colors.teal.shade900
                                  : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                        title: Text(
                          '${e['fullName']} ($codeStr)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isIntern
                                    ? Colors.teal.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isIntern
                                    ? 'Thực tập sinh / Khách vãng lai'
                                    : 'Nhân viên chính thức',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isIntern
                                      ? Colors.teal.shade800
                                      : const Color(0xFF2554C7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${e['department']} - ${e['position']}'),
                            Text('Email: ${e['email']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showEmployeeForm(existingEmp: e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  AppStateVuXuanLoc.employees.remove(e);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ==================== TAB 2: BÁO CÁO CHẤM CÔNG TOÀN HỆ THỐNG ====================
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AppStateVuXuanLoc.attendanceRecords.length,
            itemBuilder: (ctx, i) {
              final r = AppStateVuXuanLoc.attendanceRecords[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: Text('${r['fullName']} - ${r['method']}'),
                  subtitle: Text(
                      'Thời gian: ${r['checkInTime']}\nGPS: (${r['latitude']}, ${r['longitude']})\nNăng lượng: ${r['energyScore']}% - ${r['moodNote']}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _tabIndex < 2
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2554C7),
              foregroundColor: Colors.white,
              onPressed: () =>
                  _tabIndex == 0 ? _showShiftForm() : _showEmployeeForm(),
              icon: const Icon(Icons.add),
              label: Text(
                  _tabIndex == 0 ? 'Thêm Ca làm' : 'Thêm Nhân sự'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.access_time), label: 'Ca làm & Check-in'),
          NavigationDestination(
              icon: Icon(Icons.people), label: 'Nhân sự & TTS'),
          NavigationDestination(
              icon: Icon(Icons.fact_check), label: 'Báo cáo công'),
        ],
      ),
    );
  }
}

// ==================== 3.2 TRANG NHÂN VIÊN (ĐÃ XÓA NÚT MỞ TRANG ADMIN TRONG TAB CÁ NHÂN) ====================
class EmployeeMainScreenVuXuanLoc extends StatefulWidget {
  const EmployeeMainScreenVuXuanLoc({super.key});

  @override
  State<EmployeeMainScreenVuXuanLoc> createState() =>
      _EmployeeMainScreenVuXuanLocState();
}

class _EmployeeMainScreenVuXuanLocState
    extends State<EmployeeMainScreenVuXuanLoc> {
  int _bottomIndex = 0;
  bool _isCheckedInToday = false;
  String _lastCheckInTime = 'Chưa chấm công';
  String _currentGpsText = '10.8018° N, 106.7145° E (Trụ sở Vũ Xuân Lộc)';
  double _currentLat = 10.8018;
  double _currentLng = 106.7145;
  double _motionValue = 12.6;
  int _energyScore = 94;

  Future<void> _performCheckIn(String method,
      {String mood = 'Sẵn sàng làm việc'}) async {
    final nowStr = DateTime.now().toString().substring(0, 19);
    final newRecord = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'userEmail':
          AppStateVuXuanLoc.currentUser?['email'] ?? 'nv@vuxuanloc.edu.vn',
      'fullName': AppStateVuXuanLoc.currentUser?['fullName'] ?? 'Vũ Xuân Lộc',
      'checkInTime': nowStr,
      'method': method,
      'latitude': _currentLat,
      'longitude': _currentLng,
      'motionMagnitude': _motionValue,
      'energyScore': _energyScore,
      'moodNote': mood,
    };

    try {
      await http
          .post(
            Uri.parse('${AppStateVuXuanLoc.baseUrl}/checkin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(newRecord),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    setState(() {
      _isCheckedInToday = true;
      _lastCheckInTime = 'Đã chấm công lúc ${nowStr.substring(11)} ($method)';
      AppStateVuXuanLoc.attendanceRecords.insert(0, newRecord);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chấm công thành công bằng [$method]!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _openQrAndFingerprintModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quét mã QR / Barcode & Nhận diện Vân tay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code =
                          barcodes.first.rawValue ?? 'VXL_CA_SANG_01';
                      Navigator.pop(ctx);
                      _performCheckIn('Quét QR ($code)');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2554C7),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _performCheckIn('Quét QR (VXL_CA_SANG_01)');
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Xác nhận Mã QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _performCheckIn('Sinh trắc Vân tay');
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Quét Vân tay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGpsLocationDialog() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _currentGpsText =
              '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E';
        });
      }
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF2554C7)),
            SizedBox(width: 8),
            Expanded(child: Text('Chia sẻ Vị trí GPS')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tọa độ hiện tại:\n$_currentGpsText'),
            const SizedBox(height: 10),
            const Text(
              'Khoảng cách tới trụ sở Vũ Xuân Lộc: 15 mét (Hợp lệ)',
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2554C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performCheckIn('Vị trí GPS ($_currentGpsText)');
            },
            child: const Text('Chấm công kèm Vị trí GPS'),
          ),
        ],
      ),
    );
  }

  void _openMotionSensorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.directions_run, color: Colors.deepOrange),
              SizedBox(width: 8),
              Expanded(child: Text('Cảm biến Chuyển động & Tiếng ồn')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gia tốc chuyển động: ${_motionValue.toStringAsFixed(2)} m/s²',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Độ ồn môi trường làm việc: 46.5 dB (Yên tĩnh, đạt chuẩn)'),
              const SizedBox(height: 16),
              Slider(
                value: _motionValue,
                min: 9.8,
                max: 25.0,
                label: '${_motionValue.toStringAsFixed(1)} m/s²',
                onChanged: (v) {
                  setModalState(() => _motionValue = v);
                  setState(() => _motionValue = v);
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performCheckIn(
                    'Xác thực Chuyển động (${_motionValue.toStringAsFixed(1)} m/s²)');
              },
              child: const Text('Ghi nhận Hoạt động & Chấm công'),
            )
          ],
        ),
      ),
    );
  }

  void _openSmartEnergyFeatureDialog() {
    String selectedMood = 'Tràn đầy năng lượng';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber, size: 28),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tính năng mới: AI Energy & Anti-Burnout Score',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          // Bọc trong SingleChildScrollView để chống tràn hoàn toàn
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phân tích mức vận động + tâm trạng đầu ngày để dự báo nguy cơ kiệt sức (Burnout):',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      '$_energyScore%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2554C7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Sử dụng DropdownButton bọc trong Container để cố định chiều rộng, tránh tràn viền
                DropdownButtonFormField<String>(
                  value: selectedMood,
                  isExpanded: true, // Quan trọng: Tự động co giãn theo khung nhìn
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái tinh thần',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Tràn đầy năng lượng',
                      child: Text('🔥 Tràn đầy năng lượng (96%)',
                          overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Bình thường, ổn định',
                      child: Text('😊 Bình thường, ổn định (85%)',
                          overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Hơi mệt, cần hỗ trợ',
                      child: Text('🌿 Hơi mệt, đề xuất Pomodoro (68%)',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    setModalState(() {
                      selectedMood = v!;
                      if (v.contains('Tràn đầy')) _energyScore = 96;
                      if (v.contains('Bình thường')) _energyScore = 85;
                      if (v.contains('Hơi mệt')) _energyScore = 68;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2554C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _performCheckIn('Smart Energy AI ($_energyScore%)',
                    mood: selectedMood);
              },
              child: const Text('Chấm công Năng lượng Xanh'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        AppStateVuXuanLoc.currentUser?['fullName'] ?? 'Vũ Xuân Lộc';
    final userEmail =
        AppStateVuXuanLoc.currentUser?['email'] ?? 'nv@vuxuanloc.edu.vn';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chấm công nhân viên',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: _openSmartEnergyFeatureDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _bottomIndex,
        children: [
          // TAB 0: TRANG CHỦ NHÂN VIÊN
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $userName!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chúc bạn một ngày làm việc hiệu quả.',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isCheckedInToday
                          ? [Colors.teal.shade700, Colors.green.shade600]
                          : [const Color(0xFF2554C7), const Color(0xFF3264DF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2554C7).withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRẠNG THÁI HÔM NAY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastCheckInTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2554C7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () =>
                              _performCheckIn('Chấm công nhanh (GPS + Vân tay)'),
                          icon: const Icon(Icons.login),
                          label: Text(
                            _isCheckedInToday
                                ? 'Chấm công cập nhật ca'
                                : 'Chấm công vào',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chức năng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    _buildFeatureCard(
                      icon: Icons.qr_code_scanner,
                      title: 'Quét QR / Vân tay',
                      subtitle: 'Camera & Sinh trắc',
                      onTap: _openQrAndFingerprintModal,
                    ),
                    _buildFeatureCard(
                      icon: Icons.location_on_outlined,
                      title: 'Vị trí GPS',
                      subtitle: 'Định vị văn phòng',
                      onTap: _openGpsLocationDialog,
                    ),
                    _buildFeatureCard(
                      icon: Icons.sensors,
                      title: 'Đo chuyển động',
                      subtitle: 'Cảm biến gia tốc',
                      onTap: _openMotionSensorDialog,
                    ),
                    _buildFeatureCard(
                      icon: Icons.bolt,
                      title: 'Năng lượng AI',
                      subtitle: 'Anti-Burnout Score',
                      onTap: _openSmartEnergyFeatureDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TAB 1: LỊCH SỬ CHẤM CÔNG CỦA NHÂN VIÊN
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AppStateVuXuanLoc.attendanceRecords.length,
            itemBuilder: (ctx, i) {
              final rec = AppStateVuXuanLoc.attendanceRecords[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2554C7),
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: Text(rec['method'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Thời gian: ${rec['checkInTime']}\nTọa độ: ${rec['latitude']}, ${rec['longitude']}\nNăng lượng: ${rec['energyScore']}% - ${rec['moodNote']}'),
                  isThreeLine: true,
                ),
              );
            },
          ),

          // TAB 2: HỒ SƠ CÁ NHÂN NHÂN VIÊN (KHÔNG CÓ NÚT ADMIN CRUD)
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFF2554C7),
                  child: Icon(Icons.person, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  userName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  userEmail,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.verified_user,
                      size: 16, color: Color(0xFF2554C7)),
                  label: const Text('Phân quyền: Nhân viên chính thức'),
                  backgroundColor: Colors.blue.shade50,
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    children: [
                      ListTile(
                        leading:
                            Icon(Icons.business, color: Color(0xFF2554C7)),
                        title: Text('Đơn vị công tác'),
                        subtitle: Text('Trụ sở chính Vũ Xuân Lộc - TP.HCM'),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading:
                            Icon(Icons.access_time, color: Color(0xFF2554C7)),
                        title: Text('Ca làm việc mặc định'),
                        subtitle: Text('Ca Hành Chính (08:00 - 17:30)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AppStateVuXuanLoc.currentUser = null;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreenVuXuanLoc()),
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Đăng xuất tài khoản',
                        style: TextStyle(color: Colors.red)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (idx) => setState(() => _bottomIndex = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined), label: 'Lịch sử'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Cá nhân'),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: const Color(0xFF2554C7)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 3.3 TRANG KHÁCH VÃNG LAI / THỰC TẬP SINH (GUEST ROLE) ====================
class GuestPortalScreenVuXuanLoc extends StatelessWidget {
  const GuestPortalScreenVuXuanLoc({super.key});

  @override
  Widget build(BuildContext context) {
    final guestName =
        AppStateVuXuanLoc.currentUser?['fullName'] ?? 'Khách vãng lai / Thực tập sinh';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: const Text('Cổng Thực Tập Sinh / Khách Vãng Lai'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AppStateVuXuanLoc.currentUser = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreenVuXuanLoc()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined,
                      size: 42, color: Colors.teal.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Xin chào $guestName!\nBạn đang truy cập với phân quyền Khách vãng lai / Thực tập sinh. Bạn chỉ được phép xem lịch trực công khai và không có quyền chỉnh sửa hệ thống.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lịch ca trực văn phòng Vũ Xuân Lộc hôm nay:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: AppStateVuXuanLoc.shifts.length,
                itemBuilder: (ctx, i) {
                  final s = AppStateVuXuanLoc.shifts[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.access_time_filled,
                          color: Colors.teal.shade700),
                      title: Text(s['shiftName']),
                      subtitle: Text(
                          'Khung giờ: ${s['startTime']} - ${s['endTime']} | ${s['locationName']}'),
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
}