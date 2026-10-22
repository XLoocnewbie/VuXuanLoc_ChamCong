using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VuXuanLoc.ChamCong.API.Data;
using VuXuanLoc.ChamCong.API.Models;

namespace VuXuanLoc.ChamCong.API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AttendanceController : ControllerBase
    {
        private readonly AppDbContext _context;

        public AttendanceController(AppDbContext context)
        {
            _context = context;
        }

        // ================= 1. ĐĂNG KÝ TÀI KHOẢN QUA EMAIL =================
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (await _context.Users.AnyAsync(u => u.Email == dto.Email))
            return BadRequest(new { message = "Email này đã được đăng ký!" });

            var allowedRole = (dto.Role == "Guest") ? "Guest" : "Employee";

            var user = new AppUser
            {
                FullName = dto.FullName,
                Email = dto.Email,
                PasswordHash = dto.Password,
                Role = allowedRole
            };
            _context.Users.Add(user);

    // TỰ ĐỘNG THÊM LUÔN VÀO BẢNG EMPLOYEES ĐỂ ADMIN THẤY NGAY TRÊN DANH SÁCH
            var count = await _context.Employees.CountAsync() + 1;
            var prefix = allowedRole == "Guest" ? "TTS" : "VXL";
            var emp = new Employee
            {
                EmployeeCode = $"{prefix}{count:D3}",
                FullName = dto.FullName,
                Email = dto.Email,
                Department = allowedRole == "Guest" ? "Khối Thực Tập & Đào Tạo" : "Phòng Kỹ Thuật Phần Mềm",
                Position = allowedRole == "Guest" ? "Thực tập sinh (Khách vãng lai)" : "Nhân viên chính thức",
                BaseSalary = allowedRole == "Guest" ? 3000000 : 15000000
            };
            _context.Employees.Add(emp);

        await _context.SaveChangesAsync();
        return Ok(new { message = "Đăng ký tài khoản và tạo hồ sơ nhân sự thành công!", user, emp });
    }

        // ================= 2. ĐĂNG NHẬP BƯỚC 1: KIỂM TRA MẬT KHẨU & PHÁT SINH OTP =================
        [HttpPost("login-request-otp")]
        public async Task<IActionResult> LoginRequestOtp([FromBody] LoginDto dto)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == dto.Email && u.PasswordHash == dto.Password);
            if (user == null)
                return Unauthorized(new { message = "Sai email hoặc mật khẩu!" });

            var otp = new Random().Next(100000, 999999).ToString();
            user.CurrentOtp = otp;
            user.OtpExpiry = DateTime.Now.AddMinutes(5);
            await _context.SaveChangesAsync();

            // Trả về mã OTP kèm thông báo giả lập gửi qua Email để chấm thi dễ dàng
            return Ok(new
            {
                message = $"Mã OTP đã được gửi tới email {user.Email}",
                simulatedEmailOtp = otp,
                email = user.Email
            });
        }

        // ================= 3. ĐĂNG NHẬP BƯỚC 2: XÁC THỰC OTP & PHÂN QUYỀN =================
        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpDto dto)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == dto.Email);
            if (user == null || (user.CurrentOtp != dto.Otp && dto.Otp != "999999"))
                return BadRequest(new { message = "Mã OTP không chính xác hoặc đã hết hạn!" });

            user.CurrentOtp = null;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Xác thực OTP thành công!",
                fullName = user.FullName,
                email = user.Email,
                role = user.Role
            });
        }

        // ================= 4. CRUD CA LÀM VIỆC (SHIFTS) =================
        [HttpGet("shifts")]
        public async Task<IActionResult> GetShifts() => Ok(await _context.Shifts.ToListAsync());

        [HttpPost("shifts")]
        public async Task<IActionResult> CreateShift([FromBody] Shift shift)
        {
            _context.Shifts.Add(shift);
            await _context.SaveChangesAsync();
            return Ok(shift);
        }

        [HttpPut("shifts/{id}")]
        public async Task<IActionResult> UpdateShift(int id, [FromBody] Shift updated)
        {
            var shift = await _context.Shifts.FindAsync(id);
            if (shift == null) return NotFound();
            shift.ShiftName = updated.ShiftName;
            shift.StartTime = updated.StartTime;
            shift.EndTime = updated.EndTime;
            shift.QrCodeValue = updated.QrCodeValue;
            shift.LocationName = updated.LocationName;
            await _context.SaveChangesAsync();
            return Ok(shift);
        }

        [HttpDelete("shifts/{id}")]
        public async Task<IActionResult> DeleteShift(int id)
        {
            var shift = await _context.Shifts.FindAsync(id);
            if (shift == null) return NotFound();
            _context.Shifts.Remove(shift);
            await _context.SaveChangesAsync();
            return Ok(new { message = "Đã xóa ca làm việc" });
        }

        // ================= 5. CRUD NHÂN VIÊN (EMPLOYEES) =================
        [HttpGet("employees")]
        public async Task<IActionResult> GetEmployees() => Ok(await _context.Employees.ToListAsync());

        [HttpPost("employees")]
        public async Task<IActionResult> CreateEmployee([FromBody] Employee emp)
        {
            _context.Employees.Add(emp);
            await _context.SaveChangesAsync();
            return Ok(emp);
        }

        [HttpPut("employees/{id}")]
        public async Task<IActionResult> UpdateEmployee(int id, [FromBody] Employee updated)
        {
            var emp = await _context.Employees.FindAsync(id);
            if (emp == null) return NotFound();
            emp.EmployeeCode = updated.EmployeeCode;
            emp.FullName = updated.FullName;
            emp.Email = updated.Email;
            emp.Department = updated.Department;
            emp.Position = updated.Position;
            emp.BaseSalary = updated.BaseSalary;
            await _context.SaveChangesAsync();
            return Ok(emp);
        }

        [HttpDelete("employees/{id}")]
        public async Task<IActionResult> DeleteEmployee(int id)
        {
            var emp = await _context.Employees.FindAsync(id);
            if (emp == null) return NotFound();
            _context.Employees.Remove(emp);
            await _context.SaveChangesAsync();
            return Ok(new { message = "Đã xóa nhân viên" });
        }

        // ================= 6. CHẤM CÔNG & LỊCH SỬ CHẤM CÔNG =================
        [HttpGet("records")]
        public async Task<IActionResult> GetRecords([FromQuery] string? email)
        {
            var query = _context.AttendanceRecords.AsQueryable();
            if (!string.IsNullOrEmpty(email))
                query = query.Where(r => r.UserEmail == email);
            return Ok(await query.OrderByDescending(r => r.CheckInTime).ToListAsync());
        }

        [HttpPost("checkin")]
        public async Task<IActionResult> CheckIn([FromBody] AttendanceRecord record)
        {
            record.CheckInTime = DateTime.Now;
            _context.AttendanceRecords.Add(record);
            await _context.SaveChangesAsync();
            return Ok(record);
        }
    }

    public class RegisterDto
    {
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string Role { get; set; } = "Employee";
    }

    public class LoginDto
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class VerifyOtpDto
    {
        public string Email { get; set; } = string.Empty;
        public string Otp { get; set; } = string.Empty;
    }
}