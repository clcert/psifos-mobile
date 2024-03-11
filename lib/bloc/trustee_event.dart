sealed class TrusteeEvent {}

final class InitialDataLoaded extends TrusteeEvent {
  final String electionShortName;
  final String trusteeName;

  InitialDataLoaded({required this.electionShortName, required this.trusteeName});
}

final class CertGenerated extends TrusteeEvent {}

final class TrusteeSynchronized extends TrusteeEvent {}

final class TallyDecrypted extends TrusteeEvent {}
