import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'security_service.dart';
import '../screens/customers_screen.dart';
import '../theme/design_system.dart';

/// Reusable receipt generation helper.
///
/// Provides QR code display, WhatsApp sending, and the choice dialog
/// for any module (retail, restaurant, services, entertainment, lodging).
class ReceiptHelper {
  ReceiptHelper._(); // Prevent instantiation

  // ──────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ──────────────────────────────────────────────────────────────────

  /// Shows a dialog asking the user to choose QR Share, WhatsApp, or Skip.
  ///
  /// [items] is an optional list of `{'name': ..., 'qty': ..., 'price': ...}`
  /// maps used by the QR and WhatsApp formatters.  Pass `null` for simple
  /// income/expense transactions without line items.
  ///
  /// Returns when the dialog is dismissed.
  static Future<void> showReceiptDialog(
    BuildContext context, {
    required double total,
    required int timestamp,
    required String signature,
    required String txnType,
    String? details,
    List<Map<String, dynamic>>? items,
    /// If true, pops the calling screen after the dialog is dismissed.
    bool popAfter = false,
  }) async {
    final title =
        txnType == 'outgoing' ? 'Expense Recorded' : 'Transaction Successful';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content:
            const Text('Send a digital receipt for this transaction?'),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showReceiptQr(
                      context,
                      total: total,
                      timestamp: timestamp,
                      signature: signature,
                      items: items,
                      popAfter: popAfter,
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('QR Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleWhatsAppFlow(
                      context,
                      total: total,
                      timestamp: timestamp,
                      signature: signature,
                      txnType: txnType,
                      details: details,
                      items: items,
                      popAfter: popAfter,
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (popAfter && Navigator.canPop(context)) {
                Navigator.pop(context, true);
              }
            },
            child:
                const Text('NO, SKIP', style: TextStyle(color: Colors.grey)),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
      ),
    );
  }

  /// Convenience: sign a transaction that was never signed before
  /// (e.g. old records created before signatures were added).
  static Future<String> ensureSignature({
    required int timestamp,
    required num totalAmount,
    required String type,
    String? details,
    String? existingSignature,
  }) async {
    if (existingSignature != null && existingSignature.isNotEmpty) {
      return existingSignature;
    }
    return SecurityService().signTransaction(
      timestamp: timestamp,
      totalAmount: totalAmount,
      type: type,
      details: details,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  QR CODE
  // ──────────────────────────────────────────────────────────────────

  static Future<void> _showReceiptQr(
    BuildContext context, {
    required double total,
    required int timestamp,
    required String signature,
    List<Map<String, dynamic>>? items,
    bool popAfter = false,
  }) async {
    final shop = await AuthService.getCurrentShop();
    final shopName = shop?.businessName ?? 'Mbeck Shop';

    final receiptMap = <String, dynamic>{
      's': shopName,
      't': total,
      'd': timestamp,
      'sig': signature.length >= 8 ? signature.substring(0, 8) : signature,
    };

    if (items != null && items.isNotEmpty) {
      receiptMap['i'] = items
          .map((i) => {
                'n': i['name'] ?? i['n'] ?? '',
                'q': i['qty'] ?? i['q'] ?? 1,
                'p': i['price'] ?? i['p'] ?? 0,
              })
          .toList();
    }

    final qrData = jsonEncode(receiptMap);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        alignment: Alignment.center,
        title: const Text('Scan for Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 260,
              height: 260,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Customer can scan this with Buyer App',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (popAfter && Navigator.canPop(context)) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  WHATSAPP FLOW
  // ──────────────────────────────────────────────────────────────────

  static Future<void> _handleWhatsAppFlow(
    BuildContext context, {
    required double total,
    required int timestamp,
    required String signature,
    required String txnType,
    String? details,
    List<Map<String, dynamic>>? items,
    bool popAfter = false,
  }) async {
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final manualPhoneCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Receipt Destination'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.contacts, color: AppColors.primaryGreen),
                title: const Text('Select from Customers'),
                onTap: () async {
                  final picked = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomersScreen(isPicker: true),
                    ),
                  );
                  Navigator.pop(ctx, picked?.toString());
                },
              ),
              const Divider(),
              const Text('Or enter number manually:'),
              TextField(
                controller: manualPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(hintText: 'e.g. 0712345678'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, manualPhoneCtrl.text),
              child: const Text('PROCEED'),
            ),
          ],
        );
      },
    );

    if (phone != null && phone.isNotEmpty) {
      await _sendWhatsAppReceipt(
        phone,
        total: total,
        timestamp: timestamp,
        signature: signature,
        txnType: txnType,
        details: details,
        items: items,
      );
    }

    if (popAfter && context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  static Future<void> _sendWhatsAppReceipt(
    String phone, {
    required double total,
    required int timestamp,
    required String signature,
    required String txnType,
    String? details,
    List<Map<String, dynamic>>? items,
  }) async {
    final now = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    final shop = await AuthService.getCurrentShop();
    final businessName = shop?.businessName ?? 'Mbeck Shop';

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '254${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('254') && cleanPhone.length == 9) {
      cleanPhone = '254$cleanPhone';
    }

    final buf = StringBuffer();
    buf.writeln('🧾 *$businessName*');
    buf.writeln('----------------------------');
    buf.writeln('Type: ${txnType.toUpperCase()}');

    if (items != null) {
      for (final item in items) {
        final name = item['name'] ?? item['n'] ?? 'Item';
        final qty = item['qty'] ?? item['q'] ?? 1;
        final price = item['price'] ?? item['p'] ?? 0;
        final subtotal = (qty as num) * (price as num);
        buf.writeln('$name x$qty = KSH $subtotal');
      }
    } else if (details != null && details.isNotEmpty) {
      buf.writeln(details);
    }

    buf.writeln('*Total: KSH $total*');
    buf.writeln('----------------------------');
    final tsStr = timestamp.toString();
    buf.writeln('Ref: ${tsStr.substring(tsStr.length - 6)}');
    buf.writeln('Security Sig: $signature');
    buf.writeln('Date: $dateStr');
    buf.writeln('Time: $timeStr');
    buf.writeln();
    buf.writeln('Thank you for your business at *$businessName*!');
    buf.writeln();
    buf.write('_Powered by Mbeck - Download for Free_');

    final message = buf.toString();
    final encodedMsg = message.replaceAll('\n', '%0A');

    final whatsappUri =
        Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
    final httpsUri = Uri.parse(
        'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(httpsUri)) {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      } else {
        Share.share(message);
      }
    } catch (e) {
      Share.share(message);
    }
  }
}
