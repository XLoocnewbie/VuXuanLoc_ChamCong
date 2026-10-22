using System.ComponentModel.DataAnnotations;

namespace VuXuanLoc.ChamCong.API.Models
{
    public class AppUser
    {
        [Key]
        public int Id { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        // Role: "Admin", "Employee", "Guest"
        public string Role { get; set; } = "Employee";
        public string? CurrentOtp { get; set; }
        public DateTime? OtpExpiry { get; set; }
    }
}