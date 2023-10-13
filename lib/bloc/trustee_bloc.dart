import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psifos_mobile_crypto/psifos_crypto.dart';
import 'package:psifos_mobile_app/services/api.dart';
import 'trustee_event.dart';
import 'trustee_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TrusteeBloc extends Bloc<TrusteeEvent, TrusteeState> {
  final ApiService apiService;
  late String randomness;
  late Map<String, dynamic> egParams;

  final secureStorage = const FlutterSecureStorage();
  final StreamController<int> _trusteeStepController = StreamController<int>();

  TrusteeBloc({required this.apiService}) : super(const TrusteeInitial()) {
    on<InitialDataLoaded>(_onInitialDataLoaded);
    on<KeyPairGenerated>(_onKeyPairGenerated);
    on<PrivateKeyValidated>(_onPrivateKeyValidated);
    on<TrusteeSynchronized>(_onTrusteeSynchronized);
    on<TallyDecrypted>(_onTallyDecripted);
  }

  Future<void> _onInitialDataLoaded(
      InitialDataLoaded event, Emitter<TrusteeState> emit) async {
    // Make HTTP GET request to retrieve eg_params
    await apiService.getEgParams().then((value) => egParams = value);

    // Make HTTP GET request to retrieve randomness
    await apiService.getRandomness().then((value) => randomness = value);

    // Transition state machine to key generation state
    emit(const TrusteeKeyGeneration());
  }

  void _onKeyPairGenerated(
      KeyPairGenerated event, Emitter<TrusteeState> emit) async {
    // Key generation business logic (crypto)
    Map<String, String> keyPair = TrusteeCrypto.generateKeyPair();
    String publicKey = keyPair['public_key']!;
    String privateKey = keyPair['private_key']!;

    // Store secret key using Flutter Secure Storage
    await secureStorage.write(key: 'private_key', value: privateKey);

    // Push Key Generation data to endpoint
    await apiService.uploadPublicKey(publicKey).then((value) {
      if (value) {
        emit(const TrusteePrivateKeyValidation());
      }
    });
  }

  void _onPrivateKeyValidated(
      PrivateKeyValidated event, Emitter<TrusteeState> emit) async {
    String? privateKey = await secureStorage.read(key: 'private_key');
    if (privateKey != null) {
      bool valid = TrusteeCrypto.validatePrivateKey(privateKey);
      if (valid) {
        await apiService.privateKeyValidated(privateKey);
        emit(const TrusteeSynchronization());
      }
    }
  }

  void _onTrusteeSynchronized(
      TrusteeSynchronized event, Emitter<TrusteeState> emit) async {
    int lastProcessedStep = 0;
    await for (var currentStep
        in apiService.pollTrusteeStep(_trusteeStepController)) {
      if (currentStep != null && lastProcessedStep != currentStep) {
        lastProcessedStep = currentStep;
        switch (currentStep) {
          case 1:
            _handleTrusteeSyncStep1();
            break;
          case 2:
            _handleTrusteeSyncStep2();
            break;
          case 3:
            _handleTrusteeSyncStep3();
            break;
          case 4:
            if (!emit.isDone) {
              _trusteeStepController.close();
              emit(const TrusteeTallyDecryption());
            }
            break;
          default:
            print('Unknown step: $currentStep');
            break;
        }
      } else {
        print('Error retrieving step: $currentStep');
      }
    }
  }

  void _onTallyDecripted(
      TallyDecrypted event, Emitter<TrusteeState> emit) async {
    Map<String, dynamic> decryptionData =
        await apiService.getPartialDecryptionData();
    Map<String, dynamic> election = decryptionData["election"]!;
    Map<String, dynamic> trustee = decryptionData["trustee"]!;
    String certificates = decryptionData["certificates"]!;
    String points = decryptionData["points"]!;

    // TODO: Tally decryption business logic (crypto)
    String? privateKey = await secureStorage.read(key: 'private_key');
    List<Map<String, dynamic>> partialDecryption = TrusteeCrypto.decryptTally(
        election,
        trustee,
        certificates,
        points,
        randomness,
        egParams,
        privateKey);

    // TODO: Push Partial Decryption data to endpoint
    await apiService.postPartialDecryption(partialDecryption);
    emit(const TrusteeKeyGeneration());
  }

  // Trustee Synchronization

  void _handleTrusteeSyncStep1() async {
    // Pull step 1 data from endpoint
    String certificates = await apiService.getTrusteeSyncStep1();

    // Feed certificates to TrusteeCrypto's handler method
    Map<String, String> trusteeSyncStepData =
        TrusteeCrypto.handleSyncStep1(certificates);
    String coefficients = trusteeSyncStepData['coefficients']!;
    String points = trusteeSyncStepData['points']!;

    // Push step 1 data to endpoint
    await apiService.postTrusteeSyncStep1(coefficients, points);
  }

  void _handleTrusteeSyncStep2() async {
    // Pull step 2 data from endpoint
    Map<String, dynamic> endpointStepData =
        await apiService.getTrusteeSyncStep2();
    String certificates = endpointStepData['certificates']!;
    String coefficients = endpointStepData['coefficients']!;
    String points = endpointStepData['points']!;

    // Feed step 2 data to TrusteeCrypto's handler method
    Map<String, String> trusteeSyncStepData =
        TrusteeCrypto.handleSyncStep2(certificates, coefficients, points);
    String akcnowledgements = trusteeSyncStepData['acknowledgements']!;

    // Push step 2 data to endpoint
    await apiService.postTrusteeSyncStep2(akcnowledgements);
  }

  void _handleTrusteeSyncStep3() async {
    // Pull step 3 data from endpoint
    Map<String, dynamic> endpointStepData =
        await apiService.getTrusteeSyncStep3();

    String certificates = endpointStepData['certificates']!;
    String coefficients = endpointStepData['coefficients']!;
    String points = endpointStepData['points']!;
    String akcnowledgements = endpointStepData['acks']!;
    String pointsSent = endpointStepData['points_sent']!;

    // Feed step 3 data to TrusteeCrypto's handler method
    Map<String, String> trusteeSyncStepData = TrusteeCrypto.handleSyncStep3(
        certificates, coefficients, points, akcnowledgements, pointsSent);
    String verificationKey = trusteeSyncStepData['verification_key']!;

    // Push step 3 data to endpoint
    await apiService.postTrusteeSyncStep3(verificationKey);
  }
}
