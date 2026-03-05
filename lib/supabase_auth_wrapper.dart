import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthWrapper extends StatelessWidget {
  final WidgetBuilder signedInBuilder;
  final WidgetBuilder nonSignedInBuilder;

  const SupabaseAuthWrapper({
    super.key,
    required this.signedInBuilder,
    required this.nonSignedInBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return signedInBuilder(context);
        } else {
          return nonSignedInBuilder(context);
        }
      },
    );
  }
}
