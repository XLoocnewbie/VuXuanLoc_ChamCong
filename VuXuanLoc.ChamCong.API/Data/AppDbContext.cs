using Microsoft.EntityFrameworkCore;
using VuXuanLoc.ChamCong.API.Models;

namespace VuXuanLoc.ChamCong.API.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<AppUser> Users { get; set; }
        public DbSet<Employee> Employees { get; set; }
        public DbSet<Shift> Shifts { get; set; }
        public DbSet<AttendanceRecord> AttendanceRecords { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Seed 3 tài khoản cho 3 quyền: Admin, Employee, Guest
            modelBuilder.Entity<AppUser>().HasData(
                new AppUser { Id = 1, FullName = "Vũ Xuân Lộc (Admin)", Email = "admin@vuxuanloc.edu.vn", PasswordHash = "123456", Role = "Admin" },
                new AppUser { Id = 2, FullName = "Vũ Xuân Lộc (Nhân viên)", Email = "nv@vuxuanloc.edu.vn", PasswordHash = "123456", Role = "Employee" },
                new AppUser { Id = 3, FullName = "Khách Tham Quan", Email = "khach@vuxuanloc.edu.vn", PasswordHash = "123456", Role = "Guest" }
            );

            // Seed dữ liệu Ca làm việc (Shift)
            modelBuilder.Entity<Shift>().HasData(
                new Shift { Id = 1, ShiftName = "Ca Sáng Hành Chính", StartTime = "08:00", EndTime = "12:00", QrCodeValue = "VXL_CA_SANG_01", LocationName = "Tòa nhà Vũ Xuân Lộc - Tầng 3" },
                new Shift { Id = 2, ShiftName = "Ca Chiều Hành Chính", StartTime = "13:00", EndTime = "17:30", QrCodeValue = "VXL_CA_CHIEU_02", LocationName = "Tòa nhà Vũ Xuân Lộc - Tầng 3" }
            );

            // Seed dữ liệu Nhân viên (Employee)
            modelBuilder.Entity<Employee>().HasData(
                new Employee { Id = 1, EmployeeCode = "VXL001", FullName = "Vũ Xuân Lộc", Email = "nv@vuxuanloc.edu.vn", Department = "Phòng Kỹ Thuật Phần Mềm", Position = "Senior Mobile Dev", BaseSalary = 18000000 },
                new Employee { Id = 2, EmployeeCode = "VXL002", FullName = "Nguyễn Văn An", Email = "an.nv@vuxuanloc.edu.vn", Department = "Phòng Nhân Sự", Position = "HR Specialist", BaseSalary = 12000000 }
            );
        }
    }
}