import 'package:flutter/material.dart';
import '../providers/instagram_provider.dart';
import '../services/instagram_api_service.dart';

class TwoFactorDialog extends StatefulWidget {
  final String username;
  final String password;
  final InstagramProvider provider;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const TwoFactorDialog({
    super.key,
    required this.username,
    required this.password,
    required this.provider,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  final InstagramApiService _apiService = InstagramApiService();

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit2FACode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your 2FA code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await widget.provider.addAccountWith2FA(
        widget.username,
        widget.password,
        _codeController.text.trim(),
      );

      if (success) {
        widget.onSuccess();
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = widget.provider.error ?? '2FA verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.orange),
          SizedBox(width: 8),
          Text('Two-Factor Authentication'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Please enter the 6-digit code from your authenticator app or the code sent to your phone/email.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                fontSize: 24,
                color: Colors.grey[400],
                letterSpacing: 2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _submit2FACode(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The code expires in 5 minutes. If you don\'t receive it, check your spam folder.',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_successMessage != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _successMessage!,
                style: const TextStyle(color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verifying 2FA code...',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _resendCode,
            child: const Text('Resend Code / Try another method'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            widget.onCancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit2FACode,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final twoFactorInfo = widget.provider.getTwoFactorInfo();
      if (twoFactorInfo != null) {
        final twoFactorIdentifier = twoFactorInfo['two_factor_info']?['two_factor_identifier'] ?? twoFactorInfo['two_factor_identifier'];
        if (twoFactorIdentifier != null) {
          await _apiService.request2FASMS(widget.username, twoFactorIdentifier);
          setState(() {
            _successMessage = 'A new code has been sent to your phone.';
          });
        } else {
          throw Exception('Could not find two_factor_identifier.');
        }
      } else {
        throw Exception('Two factor info not available.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend code: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
