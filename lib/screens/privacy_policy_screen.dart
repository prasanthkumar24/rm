import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00151C),
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF002B38),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Privacy Policy',
              'Last Updated: February 2026',
              isTitle: true,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Information We Collect',
              'RM LIVE collects your mobile number and basic device information to provide streaming services and secure access to your account. We do not sell or share this information with third parties.',
            ),
            _buildSection(
              '2. How We Use Information',
              'We use your information to verify your identity via OTP, provide personalized content recommendations, and ensure the security of our platform.',
            ),
            _buildSection(
              '3. Data Security',
              'We implement robust security measures to protect your data from unauthorized access, disclosure, or alteration. All video streaming is secured via encrypted protocols.',
            ),
            _buildSection(
              '4. Third-Party Services',
              'Our app uses Jellyfin for video streaming services. Your login credentials for the video server are stored locally and securely on your device.',
            ),
            _buildSection(
              '5. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at support@rmvideo.in.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 RM LIVE. All rights reserved.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B8CA0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: isTitle ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: isTitle ? Colors.white : const Color(0xFF3B6DCC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6B8CA0),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
