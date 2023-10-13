sealed class TrusteeEvent {}

final class InitialDataLoaded extends TrusteeEvent {}

final class KeyPairGenerated extends TrusteeEvent {}

final class PrivateKeyValidated extends TrusteeEvent {}

final class TrusteeSynchronized extends TrusteeEvent {}

final class TallyDecrypted extends TrusteeEvent {}
