import 'package:flutter/material.dart';

class TeamLogo extends StatelessWidget {
  final String? url;
  final double size;

  const TeamLogo({super.key, required this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, __) => {}, 
      );
    }
    
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.shield, size: size * 0.6, color: Colors.grey.shade700),
    );
  }
}