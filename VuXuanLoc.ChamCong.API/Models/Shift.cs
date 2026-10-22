using System.ComponentModel.DataAnnotations;

namespace VuXuanLoc.ChamCong.API.Models
{
    public class Shift
    {
        [Key]
        public int Id { get; set; }
        public string ShiftName { get; set; } = string.Empty;
        public string StartTime { get; set; } = "08:00";
        public string EndTime { get; set; } = "17:00";
        public string QrCodeValue { get; set; } = "VUXUANLOC_SHIFT_MORNING";
        public string LocationName { get; set; } = "Trụ sở Vũ Xuân Lộc - TP.HCM";
    }
}