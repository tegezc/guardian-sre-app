import 'package:flutter/material.dart';

class MetricCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String label;
  final bool isAlert;

  const MetricCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.label,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? Colors.redAccent : Colors.blueGrey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}