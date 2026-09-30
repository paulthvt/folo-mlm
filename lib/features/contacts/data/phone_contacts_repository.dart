import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/features/contacts/domain/phone_contact.dart';

/// The phone's address book, read once for the import. Nothing read here is
/// kept: only the people the user ticks are saved, through the book.
class PhoneContactsRepository {
  const PhoneContactsRepository();

  /// Asks for access the first time. Null when it is refused, now or before;
  /// then only the phone's settings can grant it. Contacts without a name are
  /// left out.
  Future<List<PhoneContact>?> read() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      return null;
    }
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.email},
    );
    return [
      for (final contact in contacts)
        if ((contact.displayName ?? '').trim() case final name
            when name.isNotEmpty)
          (
            name: name,
            phone: contact.phones.firstOrNull?.number,
            email: contact.emails.firstOrNull?.address,
          ),
    ];
  }

  Future<void> openSettings() => FlutterContacts.permissions.openSettings();
}

final phoneContactsRepositoryProvider = Provider<PhoneContactsRepository>(
  (ref) => const PhoneContactsRepository(),
);
