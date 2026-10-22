using System.ComponentModel.DataAnnotations;

namespace VuXuanLoc.ChamCong.API.Models
{
    public class Employee
    {
        [Key]
        public int Id { get; set; }
        public string EmployeeCode { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Department { get; set; } = string.Empty;
        public string Position { get; set; } = string.Empty;
        public double BaseSalary { get; set; }
    }
}