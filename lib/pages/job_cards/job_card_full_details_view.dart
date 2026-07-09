import 'package:flutter/material.dart';

class JobCardDetailsView extends StatelessWidget {
  final Map jobCardDetails;
  const JobCardDetailsView({super.key, required this.jobCardDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Job Card Details",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= BASIC INFO =================
            sectionTitle("Basic Information", Icons.info_outline),

            buildSectionCard(
              child: Column(
                children: [
                  detailRow("Vehicle Number",
                      jobCardDetails["vehicle_number"]),
                  detailRow("Assigned By",
                      jobCardDetails["assigned_by_name"]),
                  detailRow("Assigned On",
                      jobCardDetails["assigned_on"]),
                  detailRow("Work",
                      jobCardDetails["work"]),
                  detailRow("Status",
                      jobCardDetails["status"]),
                ],
              ),
            ),

            // ================= WORKFLOW =================
            sectionTitle("Workflow Details", Icons.sync),

            buildSectionCard(
              child: Column(
                children: [
                  detailRow("Work Start By",
                      jobCardDetails["work_start_by_name"]),
                  detailRow("Work Start At",
                      jobCardDetails["work_start_at"]),
                  detailRow("Mechanics",
                      jobCardDetails["mechanics"]),
                  detailRow("Work Closed By",
                      jobCardDetails["work_closed_by_name"]),
                  detailRow("Work Closed At",
                      jobCardDetails["work_closed_at"]),
                ],
              ),
            ),

            // ================= SPARE DETAILS =================
            sectionTitle("Spare Details", Icons.build),

            buildSectionCard(
              child: Column(
                children: [
                  detailRow("Spares",
                      jobCardDetails["spares"]),
                  detailRow("Spare Code",
                      jobCardDetails["spare_code"]),
                  detailRow("Spare Requested Date",
                      jobCardDetails["spare_requested_date"]),
                  detailRow("Spare Request Remark",
                      jobCardDetails["spare_request_remark"]),
                  detailRow("Spare Approved By",
                      jobCardDetails["spare_approved_by_name"]),
                  detailRow("Spare Approved On",
                      jobCardDetails["spare_approved_on"]),
                  detailRow("Spare Approval Remark",
                      jobCardDetails["spare_approval_remark"]),
                  detailRow("Cost",
                      jobCardDetails["cost"]),
                ],
              ),
            ),

            // ================= REMARKS =================
            sectionTitle("Remarks & Cancellation", Icons.note_alt),

            buildSectionCard(
              child: Column(
                children: [
                  detailRow("Work Assignee Remark",
                      jobCardDetails["work_assignee_remark"]),
                  detailRow("Vehicle Incharge Remark",
                      jobCardDetails["vehicle_incharge_remark"]),
                  detailRow("Work Canceled By",
                      jobCardDetails["work_canceled_by_name"]),
                  detailRow("Work Canceled At",
                      jobCardDetails["work_canceled_at"]),
                  detailRow("Cancel Remark",
                      jobCardDetails["cancel_remark"]),
                  detailRow("General Remark",
                      jobCardDetails["remark"]),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  Widget detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value == null || value.toString().isEmpty
                  ? "-"
                  : value.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget buildSectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

}
