import 'package:folo/features/contacts/data/phone_contacts_repository.dart';
import 'package:folo/features/contacts/domain/phone_contact.dart';

/// A phone whose address book is [contacts]; null is access refused.
class FakePhoneContactsRepository implements PhoneContactsRepository {
  FakePhoneContactsRepository([this.contacts = const []]);

  List<PhoneContact>? contacts;

  /// Thrown by [read] while set.
  Object? failWith;

  var settingsOpened = 0;

  @override
  Future<List<PhoneContact>?> read() async {
    if (failWith case final failure?) throw failure;
    return contacts;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
