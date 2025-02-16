enum TrusteeStatus {
  initial,
  certGeneration,
  privateKeyValidation,
  synchronization,
  tallyDecryption,
}

sealed class TrusteeState {
  const TrusteeState({
    this.status = TrusteeStatus.initial,
  });

  final TrusteeStatus status;
}

final class TrusteeInitial extends TrusteeState {
  const TrusteeInitial() : super(status: TrusteeStatus.initial);
}

final class TrusteeKeyGeneration extends TrusteeState {
  const TrusteeKeyGeneration() : super(status: TrusteeStatus.certGeneration);
}

final class TrusteeSynchronization extends TrusteeState {
  const TrusteeSynchronization() : super(status: TrusteeStatus.synchronization);
}

final class TrusteeTallyDecryption extends TrusteeState {
  const TrusteeTallyDecryption() : super(status: TrusteeStatus.tallyDecryption);
}
