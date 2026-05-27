import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsDetailDialog extends StatelessWidget {
  final Map<String, dynamic> news;

  const NewsDetailDialog({super.key, required this.news});

  static void show(BuildContext context, Map<String, dynamic> news) {
    showDialog(
      context: context,
      builder: (_) => NewsDetailDialog(news: news),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = news['title'] ?? '';
    final desc = news['content'] ?? '';
    final category = news['category'] ?? 'genel';
    final imageUrl = news['image_url'];
    final youtubeUrl = news['youtube_url'];
    
    Color catColor = const Color(0xFF2ECC71); 
    String catLabel = 'HABER';
    if (category == 'haftanin_11i') { catColor = Colors.blueAccent; catLabel = "HAFTANIN 11'İ"; }
    else if (category == 'haftanin_oyuncusu') { catColor = const Color(0xFFF39C12); catLabel = "HAFTANIN OYUNCUSU"; }
    else if (category == 'video') { catColor = Colors.redAccent; catLabel = "VİDEO (YOUTUBE)"; }

    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 850),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  if (hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        imageUrl, 
                        width: double.infinity, 
                        fit: BoxFit.fitWidth
                      ),
                    )
                  else if (category == 'video')
                    Container(
                      height: 350, width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 100)),
                    )
                  else
                    Container(
                      height: 100, width: double.infinity,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                    ),

                  
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15), 
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(catLabel, style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 16),
                        
                        
                        Text(title, style: const TextStyle(color: Colors.black87, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                        const SizedBox(height: 20),
                        
                        
                        if (desc.isNotEmpty) ...[
                          Text(desc, style: TextStyle(color: Colors.grey.shade800, fontSize: 16, height: 1.6)),
                          const SizedBox(height: 30),
                        ],

                        
                        if (youtubeUrl != null && youtubeUrl.toString().isNotEmpty)
                          Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () async {
                                final uri = Uri.parse(youtubeUrl);
                                if (await canLaunchUrl(uri)) await launchUrl(uri);
                              },
                              icon: const Icon(Icons.play_circle_outline, size: 28),
                              label: const Text("YOUTUBE'DA İZLE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            
            Positioned(
              top: 10, right: 10,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
