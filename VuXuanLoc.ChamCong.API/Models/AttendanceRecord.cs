using System.ComponentModel.DataAnnotations;

namespace VuXuanLoc.ChamCong.API.Models
{
    public class AttendanceRecord
    {
        [Key]
        public int Id { get; set; }
        public string UserEmail { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public DateTime CheckInTime { get; set; } = DateTime.Now;
        public string Method { get; set; } = "GPS + QR"; // QR, GPS, Fingerprint
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public double MotionMagnitude { get; set; } // Đo chuyển động
        public int EnergyScore { get; set; } = 95; // Tính năng mới đề xuất
        public string MoodNote { get; set; } = "Tràn đầy năng lượng";
    }
}