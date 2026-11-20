import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentConfig {
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String jazzCashNumber;
  final String easyPaisaNumber;
  final String adminWhatsApp;
  final String monthlyFee;
  final String annualFee;

  const PaymentConfig({
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.jazzCashNumber,
    required this.easyPaisaNumber,
    required this.adminWhatsApp,
    required this.monthlyFee,
    required this.annualFee,
  });

  static const PaymentConfig defaults = PaymentConfig(
    bankName: 'Meezan Bank Ltd.',
    accountTitle: 'Smart SMS SaaS Portal',
    accountNumber: '01020304050607',
    jazzCashNumber: '03336387744',
    easyPaisaNumber: '03336387744',
    adminWhatsApp: '03336387744',
    monthlyFee: 'Rs. 3,000 / Month',
    annualFee: 'Rs. 25,000 / Year',
  );

  factory PaymentConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return PaymentConfig(
      bankName: data['bankName']?.toString() ?? defaults.bankName,
      accountTitle: data['accountTitle']?.toString() ?? defaults.accountTitle,
      accountNumber: data['accountNumber']?.toString() ?? defaults.accountNumber,
      jazzCashNumber: data['jazzCashNumber']?.toString() ?? defaults.jazzCashNumber,
      easyPaisaNumber: data['easyPaisaNumber']?.toString() ?? defaults.easyPaisaNumber,
      adminWhatsApp: data['adminWhatsApp']?.toString() ?? defaults.adminWhatsApp,
      monthlyFee: data['monthlyFee']?.toString() ?? defaults.monthlyFee,
      annualFee: data['annualFee']?.toString() ?? defaults.annualFee,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'accountTitle': accountTitle,
      'accountNumber': accountNumber,
      'jazzCashNumber': jazzCashNumber,
      'easyPaisaNumber': easyPaisaNumber,
      'adminWhatsApp': adminWhatsApp,
      'monthlyFee': monthlyFee,
      'annualFee': annualFee,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class PaymentConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'app_config';
  static const String _docId = 'payment_info';

  /// Stream payment configuration in real-time
  static Stream<PaymentConfig> get paymentConfigStream {
    return _firestore.collection(_collection).doc(_docId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return PaymentConfig.fromMap(snap.data());
      }
      return PaymentConfig.defaults;
    });
  }

  /// Fetch payment configuration once with default fallback
  static Future<PaymentConfig> fetchPaymentConfig() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();
      if (doc.exists && doc.data() != null) {
        return PaymentConfig.fromMap(doc.data());
      }
      // If document doesn't exist yet, seed defaults in background
      _firestore.collection(_collection).doc(_docId).set(
        PaymentConfig.defaults.toMap(),
        SetOptions(merge: true),
      ).catchError((e) {
        debugPrint('Notice seeding payment_info defaults: $e');
      });
      return PaymentConfig.defaults;
    } catch (e) {
      debugPrint('Error fetching payment_info, using defaults: $e');
      return PaymentConfig.defaults;
    }
  }

  /// Save payment configuration (Super Admin only)
  static Future<void> savePaymentConfig(PaymentConfig config) async {
    await _firestore.collection(_collection).doc(_docId).set(
      config.toMap(),
      SetOptions(merge: true),
    );
  }

  /// Clean Pakistani/International phone number for WhatsApp wa.me link
  static String formatPhoneForWhatsApp(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0092')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0')) {
      clean = '92${clean.substring(1)}';
    } else if (clean.length == 10 && !clean.startsWith('92')) {
      clean = '92$clean';
    }
    return clean;
  }

  /// Launch WhatsApp with pre-filled message
  static Future<bool> launchWhatsApp({required String phone, required String message}) async {
    final cleanPhone = formatPhoneForWhatsApp(phone);
    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }
}
