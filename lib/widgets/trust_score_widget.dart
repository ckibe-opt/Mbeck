import 'package:flutter/material.dart';

class TrustScoreWidget extends StatelessWidget {
  final double score;
  final double size;

  const TrustScoreWidget({
    Key? key,
    required this.score,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine color based on score
    // >= 80 is Gold, >= 50 is Silver, below is Bronze
    final isGold = score >= 80.0;
    final isSilver = score >= 50.0;
    final color = isGold 
        ? const Color(0xFFFFD700) 
        : (isSilver ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    
    return Tooltip(
      message: 'Trust Score: ${score.toStringAsFixed(0)} / 100',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user, // Shield icon
            color: color,
            size: size,
          ),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: size * 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
