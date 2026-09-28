/// Where someone is in the relationship. One stage at a time; people move
/// forward and sometimes back (#56).
enum Stage { prospect, customer, team }

/// How a prospect conversation stands. Only prospects have one.
enum ProspectStatus { interested, thinking, notNow, noReply }

/// Someone in the user's book.
///
/// Every text field is optional except [name]. A blank value is stored as null,
/// never as an empty string.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.stage,
    required this.createdAt,
    this.prospectStatus,
    this.phone,
    this.email,
    this.instagram,
    this.needs,
    this.products,
    this.profession,
    this.address,
    this.notes,
  }) : assert(
         prospectStatus == null || stage == Stage.prospect,
         'Only prospects have a status',
       );

  final String id;
  final String name;
  final Stage stage;

  /// When they were added, which is when their current stage began until
  /// stage changes are recorded (#56).
  final DateTime createdAt;
  final ProspectStatus? prospectStatus;
  final String? phone;
  final String? email;
  final String? instagram;

  /// Free text: "Sleep, stress, dry skin".
  final String? needs;

  /// Free text: what they already use.
  final String? products;
  final String? profession;
  final String? address;
  final String? notes;

  Person withStatus(ProspectStatus? status) => Person(
    id: id,
    name: name,
    stage: stage,
    createdAt: createdAt,
    prospectStatus: status,
    phone: phone,
    email: email,
    instagram: instagram,
    needs: needs,
    products: products,
    profession: profession,
    address: address,
    notes: notes,
  );
}

/// What Add someone collects.
typedef PersonDraft = ({
  String name,
  Stage stage,
  String? phone,
  String? email,
  String? instagram,
});
