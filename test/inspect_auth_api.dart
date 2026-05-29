import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null && user.identities != null) {
    for (final identity in user.identities!) {
      if (identity.provider == 'google') {
        Supabase.instance.client.auth.unlinkIdentity(identity);
      }
    }
  }
}
