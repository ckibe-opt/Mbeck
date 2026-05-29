
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mbeck_go/database/app_database.dart';

class ReceiptWidget extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onTap;

  const ReceiptWidget({
    super.key,
    required this.receipt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(receipt.timestamp);
    final time = DateFormat.jm().format(receipt.timestamp);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: CustomPaint(
          painter: _ReceiptShadowPainter(),
          child: ClipPath(
            clipper: _JaggedEdgeClipper(),
            child: Container(
              color: const Color(0xFFFDFDFD), // Off-white receipt paper
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          receipt.sellerName.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Courier', // Monospace like a receipt
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$date  $time',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '----------------------------',
                          style: TextStyle(fontFamily: 'Courier', color: Colors.black26),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  
                  // Itemized List
                  ..._buildItemsList(receipt.itemsJson),
                  
                  const Text(
                    '----------------------------',
                    style: TextStyle(fontFamily: 'Courier', color: Colors.black26),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'KSH ${receipt.totalAmount}',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Verification Info
                  Text(
                    'Ref: ${receipt.id.substring(receipt.id.length - 6).toUpperCase()}',
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black54),
                  ),
                  Text(
                    'Sig: ${receipt.signature.length > 8 ? receipt.signature.substring(0, 8) : receipt.signature}',
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black54),
                  ),
                  
                  const SizedBox(height: 12),
                  // Barcode-ish decoration
                  SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(40, (index) {
                        return Container(
                          width: index % 3 == 0 ? 2 : 1,
                          height: 20,
                          color: Colors.black26,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8), // Spacing for jagged edge
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItemsList(String itemsJson) {
    try {
      final List<dynamic> items = jsonDecode(itemsJson);
      return items.map((item) {
        final name = item['n'] ?? item['name'] ?? 'Item';
        final qty = item['q'] ?? item['qty'] ?? 1;
        final price = item['p'] ?? item['price'] ?? (item['subtotal'] ?? 0) / qty;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '$name x$qty = KSH ${(qty * price).toStringAsFixed(1)}',
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        );
      }).toList();
    } catch (e) {
      return [const Text('No items listed', style: TextStyle(fontFamily: 'Courier', color: Colors.black45, fontSize: 12))];
    }
  }
}

class _JaggedEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 10);
    
    double x = 0;
    double y = size.height - 10;
    double increment = 10; 
    
    while (x < size.width) {
      x += increment;
      y = (y == size.height - 10) ? size.height : size.height - 10;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ReceiptShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPath = Path();
    shadowPath.lineTo(0, size.height - 10);
    
    double x = 0;
    double y = size.height - 10;
    double increment = 10; 
    
    while (x < size.width) {
      x += increment;
      y = (y == size.height - 10) ? size.height : size.height - 10;
      shadowPath.lineTo(x, y);
    }
    
    shadowPath.lineTo(size.width, 0);
    shadowPath.close();

    canvas.drawShadow(shadowPath, Colors.black26, 4.0, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
