import 'package:flutter/material.dart';

import '../../shared/widgets/controls.dart';

/// P1 short, read-only policy summaries shown during registration.
const termsText =
    '\n'
    'P1 Terms of Use\n'
    '\n'
    'This demonstration application is for a school project. Any marketplace '
    'purchases use Cash on Delivery (COD) or meet-up only; no online payment '
    'occurs in this environment. Accounts and data are disposable test '
    'material. You may browse the catalog, create orders via cargo-of-choice, '
    'and, if approved, sell as a reseller. The marketplace does not currently '
    'support returns, disputes, or real deliveries. By continuing you agree to '
    'use the app for demonstration purposes only.';

const privacyText =
    '\n'
    'P1 Privacy Notice\n'
    '\n'
    'We collect the details you provide (name, email, contact number, and any '
    'addresses you save) only to operate this demonstration marketplace. '
    'Credentials are not committed to source control, and passwords are never '
    'stored on the device. No analytics or advertising tracking is used. '
    'Because this is a school demonstration, treat every listed product as '
    'sample data.';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MarketplaceAppBar(title: Text(title), backFallback: '/register'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, textAlign: TextAlign.justify),
      ),
    );
  }
}
