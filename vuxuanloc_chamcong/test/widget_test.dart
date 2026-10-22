import 'package:flutter_test/flutter_test.dart';
import 'package:vuxuanloc_chamcong/main.dart';

void main() {
  testWidgets('VuXuanLoc ChamCong smoke test', (WidgetTester tester) async {
    // Khởi chạy ứng dụng Vũ Xuân Lộc Chấm Công
    await tester.pumpWidget(const VuXuanLocChamCongApp());

    // Kiểm tra màn hình đăng nhập hiển thị đúng tên cá nhân
    expect(find.text('VŨ XUÂN LỘC - CHẤM CÔNG'), findsOneWidget);
  });
}